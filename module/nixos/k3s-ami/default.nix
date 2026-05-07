# services.blackmatter.k3s-ami — NixOS module body.
#
# Imports the typed option surface from ./options.nix, then composes
# the typed values into concrete NixOS configuration: services.k3s,
# k3s-bootstrap.service, services.blackmatter.fluxcd, runtime tooling,
# kernel + nix tuning.
#
# This module is a pure function of its options — every per-cluster
# value flows from SSM at first-boot via k3s-bootstrap.tlisp. The
# AMI is generic; one bake per (variant × architecture × platform)
# tuple serves every cluster on that platform.
#
# The bootstrap script lives next to the module (./k3s-bootstrap.tlisp)
# rather than being generated from typed options — the script is
# already strongly-typed via its SSM key contract, and lifting it into
# generated form is a substantial follow-up not blocking this iteration.

{ nixosHelpers ? null }:

{ config, lib, pkgs, modulesPath, ... }:

with lib;

let
  cfg = config.services.blackmatter.k3s-ami;

  # Resolve the bootstrap script. Lives in this module's directory so
  # it ships with blackmatter-kubernetes — no kindling-profiles dep.
  k3sBootstrapScript = ./k3s-bootstrap.tlisp;

  # ssm-runtime is the only currently-implemented variant in this
  # module body. kindling-init is reserved as an option value but
  # routes through a separate module path (legacy kindling-profiles
  # consumers retain their own implementation until migrated). When
  # variant=kindling-init is set on a config that imports this module,
  # the assertion below fires.
  variantImplemented = cfg.variant == "ssm-runtime";

in
{
  # Bring the option surface into scope.
  imports = [
    (import ./options.nix { inherit lib; })
    "${modulesPath}/virtualisation/amazon-image.nix"
  ];

  config = mkIf cfg.enable {

    # ── Sanity checks ───────────────────────────────────────────────
    assertions = [
      {
        assertion = variantImplemented;
        message = ''
          services.blackmatter.k3s-ami.variant = "${cfg.variant}" is
          not yet implemented in blackmatter-kubernetes. Currently
          only "ssm-runtime" is supported. To use kindling-init,
          import the legacy profiles/k3s-cloud-server module from
          kindling-profiles directly (deprecated path).
        '';
      }
      # bootstrap.fluxcd.enable=true with null source/sopsPath is OK —
      # in SSM-runtime mode, gotk-components.yaml is baked but the
      # real source URL/branch/path/token arrive at first-boot via SSM
      # (see k3s-bootstrap.tlisp's fluxcd phase). The source/sopsPath
      # slots are informational hints to the bake driver about which
      # SSM keys the consumer Pangea workspace should push.
    ];

    # ── Locale + state version ──────────────────────────────────────
    # Hostname is intentionally NOT set here — amazon-image.nix sets it
    # to "" by default and the bootstrap script overrides via instance
    # tag at first boot (matches the SSM-runtime invariant: AMI is
    # generic, per-cluster identity flows from SSM).
    time.timeZone = mkDefault "UTC";
    i18n.defaultLocale = mkDefault "en_US.UTF-8";
    system.stateVersion = mkDefault "25.11";

    # ── Networking — K3s API + node-to-node + Cilium vxlan ───────────
    # SG enforces operator-IP allowlist on :22 + :6443; the in-instance
    # firewall is defense-in-depth.
    networking.firewall.allowedTCPPorts = [
      22       # SSH
      6443     # K3s API
      10250    # kubelet (internal but K3s opens for metrics-server)
      10257    # kube-controller-manager
      10259    # kube-scheduler
    ];
    networking.firewall.allowedUDPPorts = [
      8472     # Cilium vxlan tunnel (only when cni=cilium)
    ];

    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
      };
    };

    # ── K3s service (gated on first-boot completion) ────────────────
    services.k3s = {
      enable = true;
      role = "server";
      extraFlags = [
        "--config=/etc/rancher/k3s/config.yaml"
      ];
    };

    systemd.services.k3s = {
      after = [ "network-online.target" "k3s-bootstrap.service" ];
      requires = [ "k3s-bootstrap.service" ];
      unitConfig.ConditionPathExists = "/var/lib/k3s-bootstrap-complete";
    };

    # ── FluxCD GitOps (runtime-config mode) ─────────────────────────
    # services.blackmatter.fluxcd's `conditionPath` flag flips the
    # module into "kindling-gated" mode:
    #   * gotk-components.yaml is ALWAYS baked — cluster-agnostic
    #   * gotk-sync.yaml is NOT baked          — runtime piece writes it
    # k3s-bootstrap.tlisp materializes gotk-sync from SSM at first-boot.
    services.blackmatter.fluxcd = mkIf cfg.bootstrap.fluxcd.enable {
      enable = true;
      conditionPath = "/var/lib/kindling/fluxcd-ready";
      source = {
        url = "";              # not baked (conditionPath set)
        branch = "main";       # default; runtime gotk-sync overrides
        interval = "1m0s";
        auth = "token";
        tokenFile = "/var/lib/k3s-fluxcd/github-token";
      };
      reconcile = {
        path = "";             # not baked
        interval = "2m0s";
        prune = true;
      };
    };

    # ── First-boot bootstrap (tatara-script) ────────────────────────
    # Reads instance tag pleme:k3s:ssm-prefix → ssm get-parameters-by-path
    # → writes CAs + config.yaml + Cilium manifest + Route53 A record +
    # FluxCD gotk-sync (if enabled) + image-pull-secret manifests.
    systemd.services.k3s-bootstrap = {
      description = "K3s bootstrap: SSM → CA files + config + manifests";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = with pkgs; [
        tatara-script
        awscli2
        curl
        coreutils
        bash
      ];
      unitConfig = {
        # Idempotency: skip if already complete.
        ConditionPathExists = "!/var/lib/k3s-bootstrap-complete";
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.tatara-script}/bin/tatara-script ${k3sBootstrapScript}";
      };
    };

    # ── Required runtime tooling ────────────────────────────────────
    environment.systemPackages = with pkgs; [
      k3s          # kubectl etc.
      awscli2      # for k3s-bootstrap + operator break-glass
      curl
      htop
      lsof
    ];

    # ── Boot + system tuning ────────────────────────────────────────
    boot.kernelParams = [ "transparent_hugepage=never" ];
    boot.loader.timeout = mkDefault 3;
    powerManagement.cpuFreqGovernor = mkDefault "performance";

    services.journald.extraConfig = ''
      Storage=volatile
      SystemMaxUse=200M
    '';

    systemd.network.wait-online.enable = false;

    nix.settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
    };
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };

    services.smartd.enable = false;
    services.fstrim.enable = true;
    services.udev.extraRules = ''
      ACTION=="add|change", KERNEL=="nvme[0-9]n1", ATTR{queue/scheduler}="none"
      ACTION=="add|change", KERNEL=="nvme[0-9]n1", ATTR{queue/nr_requests}="1024"
    '';
  };
}
