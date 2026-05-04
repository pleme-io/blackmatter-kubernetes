# NixOS k3s module with cluster profile support
#
# Provides services.blackmatter.k3s with comprehensive options for
# running k3s as server or agent. Uses substrate nixos-service-helpers.
#
# Profile support: setting `profile` auto-configures disable flags,
# extra flags, firewall, and kernel modules from a pre-canned profile.
# All profile-set values use mkDefault — the user can still override.
{ nixosHelpers }:

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.blackmatter.k3s;

  profileDefs = import ../../../lib/profiles.nix { inherit lib; };
  profileNames = attrNames profileDefs.profiles;
  activeProfile =
    if cfg.profile != null
    then profileDefs.profiles.${cfg.profile}
    else null;

  disableFlags = map (comp: "--disable ${comp}") cfg.disable;

  # ── CIS hardening auto-appended flags ──────────────────────────────
  # Each knob maps to a specific CIS Kubernetes Benchmark control. Flags
  # are inserted via `mkDefault`-driven extraFlags so user config can
  # still suppress any individual knob.
  cisKubeletFlags =
    optional cfg.cisHardening.readOnlyPortDisabled "--kubelet-arg=read-only-port=0"
    ++ optional cfg.cisHardening.anonymousAuthDisabled "--kubelet-arg=anonymous-auth=false"
    ++ optional cfg.cisHardening.authorizationModeWebhook "--kubelet-arg=authorization-mode=Webhook"
    ++ optional cfg.cisHardening.makeIptablesUtilChains "--kubelet-arg=make-iptables-util-chains=true"
    ++ optional cfg.cisHardening.protectKernelDefaults "--protect-kernel-defaults=true"
    # Seccomp default: runtime_default enables kubelet --seccomp-default,
    # which makes every pod inherit the container runtime's restrictive
    # profile unless explicitly overridden. Required at CIS Level 2+.
    ++ optional (cfg.seccompProfile.kind == "runtime_default") "--kubelet-arg=seccomp-default=true";

  # ── Audit policy flags (apiserver) ─────────────────────────────────
  auditPolicyFile =
    if cfg.auditPolicy.enable && cfg.auditPolicy.policyPath != null
    then cfg.auditPolicy.policyPath
    else null;

  auditApiserverFlags =
    optional (cfg.auditPolicy.enable && auditPolicyFile != null)
      "--kube-apiserver-arg=audit-policy-file=${auditPolicyFile}"
    ++ optional cfg.auditPolicy.enable
      "--kube-apiserver-arg=audit-log-path=${cfg.auditPolicy.logPath}"
    ++ optional cfg.auditPolicy.enable
      "--kube-apiserver-arg=audit-log-maxage=${toString cfg.auditPolicy.logMaxAgeDays}"
    ++ optional cfg.auditPolicy.enable
      "--kube-apiserver-arg=audit-log-maxbackup=${toString cfg.auditPolicy.logMaxBackups}"
    ++ optional cfg.auditPolicy.enable
      "--kube-apiserver-arg=audit-log-maxsize=${toString cfg.auditPolicy.logMaxSizeMb}";

  hardeningFlags = cisKubeletFlags ++ auditApiserverFlags;

  serverFlags =
    disableFlags
    ++ [ "--cluster-cidr ${cfg.clusterCIDR}" ]
    ++ [ "--service-cidr ${cfg.serviceCIDR}" ]
    ++ [ "--cluster-dns ${cfg.clusterDNS}" ]
    ++ [ "--data-dir ${cfg.dataDir}" ]
    ++ optional cfg.clusterInit "--cluster-init"
    ++ optional cfg.disableAgent "--disable-agent"
    ++ optional (cfg.serverAddr != "") "--server ${cfg.serverAddr}"
    ++ optional (cfg.tokenFile != null) "--token-file ${cfg.tokenFile}"
    ++ optional (cfg.token != "") "--token ${cfg.token}"
    ++ optional (cfg.agentTokenFile != null) "--agent-token-file ${cfg.agentTokenFile}"
    ++ optional (cfg.agentToken != "") "--agent-token ${cfg.agentToken}"
    ++ optional (cfg.nodeName != null) "--node-name ${cfg.nodeName}"
    ++ map (l: "--node-label ${l}") cfg.nodeLabel
    ++ map (t: "--node-taint ${t}") cfg.nodeTaint
    ++ optional (cfg.nodeIP != null) "--node-ip ${cfg.nodeIP}"
    ++ optional (cfg.configPath != null) "--config ${cfg.configPath}"
    ++ optional (cfg.containerdConfigTemplate != null)
      "--containerd-config-template ${
        pkgs.writeText "containerd-config-template.toml" cfg.containerdConfigTemplate
      }"
    ++ hardeningFlags
    ++ cfg.extraFlags;

  # Agents only accept kubelet-level hardening (apiserver flags are
  # server-only); CIS kubelet knobs apply here too.
  agentFlags =
    [ "--data-dir ${cfg.dataDir}" ]
    ++ optional (cfg.serverAddr != "") "--server ${cfg.serverAddr}"
    ++ optional (cfg.tokenFile != null) "--token-file ${cfg.tokenFile}"
    ++ optional (cfg.token != "") "--token ${cfg.token}"
    ++ optional (cfg.nodeName != null) "--node-name ${cfg.nodeName}"
    ++ map (l: "--node-label ${l}") cfg.nodeLabel
    ++ map (t: "--node-taint ${t}") cfg.nodeTaint
    ++ optional (cfg.nodeIP != null) "--node-ip ${cfg.nodeIP}"
    ++ optional (cfg.configPath != null) "--config ${cfg.configPath}"
    ++ cisKubeletFlags
    ++ cfg.extraFlags;

  # ── Role sentinel list helpers (for ConditionPathExists OR-semantics) ──
  # When the same condition is specified multiple times, systemd treats
  # them as OR (any match => condition satisfied). We emit one line per
  # candidate sentinel via a multiline string so the drop-in generator
  # produces repeated `ConditionPathExists=` entries.
  # Reference: systemd.unit(5) — conditions and assertions.
  serverSentinelPaths =
    optional (cfg.roleSentinels ? "server-init") cfg.roleSentinels."server-init"
    ++ optional (cfg.roleSentinels ? "server-join") cfg.roleSentinels."server-join";

  agentSentinelPaths =
    optional (cfg.roleSentinels ? "agent") cfg.roleSentinels."agent"
    ++ optional (cfg.roleSentinels ? "agent-gpu") cfg.roleSentinels."agent-gpu"
    ++ optional (cfg.roleSentinels ? "agent-storage") cfg.roleSentinels."agent-storage"
    ++ optional (cfg.roleSentinels ? "agent-ingress") cfg.roleSentinels."agent-ingress";

  # systemd supports multiple same-name ConditionPathExists entries via
  # repeated lines rendered as a string with newlines. The NixOS
  # systemd generator accepts `list` values for repeated conditions.
  mkRoleSentinelConditions = paths:
    if paths == [] then {} else { ConditionPathExists = paths; };

  flags = if cfg.role == "server" then serverFlags else agentFlags;

  # Shared Kubernetes base config (kernel modules, sysctl, DNS check, options)
  base = import ../../../lib/kubernetes-base.nix { inherit lib pkgs; };

  dnsCheckScript = base.mkDnsCheckScript {
    name = "k3s";
    timeout = cfg.waitForDNS.timeout;
  };

  # NVIDIA post-start script
  nvidiaPostStartScript = pkgs.writeShellScript "k3s-nvidia-setup" ''
    echo "Configuring NVIDIA runtime for containerd..."
    sleep 10
    for i in $(seq 1 30); do
      if [ -S /run/k3s/containerd/containerd.sock ]; then
        echo "Containerd socket ready!"
        break
      fi
      echo "Waiting for containerd socket... ($i/30)"
      sleep 2
    done
    echo "NVIDIA runtime configuration complete"
  '';

in {
  options.services.blackmatter.k3s = {
    enable = mkEnableOption "k3s Kubernetes distribution";

    profile = mkOption {
      type = types.nullOr (types.enum profileNames);
      default = null;
      description = ''
        Cluster profile — pre-canned configuration for CNI, ingress,
        firewall, and kernel modules. When set, profile values become
        defaults that can still be overridden individually.

        Available profiles: ${concatStringsSep ", " profileNames}
      '';
      example = "cilium-standard";
    };

    distribution = mkOption {
      type = types.enum [ "1.30" "1.31" "1.32" "1.33" "1.34" "1.35" ];
      default = "1.34";
      description = "Kubernetes distribution track (maps to k3s version)";
    };

    package = mkOption {
      type = types.package;
      default = let
        trackPkg = "blackmatter-k3s-${builtins.replaceStrings ["."] ["-"] cfg.distribution}";
      in pkgs.${trackPkg} or pkgs.blackmatter-k3s or pkgs.k3s;
      defaultText = literalExpression "pkgs.blackmatter-k3s";
      description = "k3s package to use (auto-selected from distribution track)";
    };

    role = mkOption {
      type = types.enum [ "server" "agent" ];
      default = "server";
      description = "k3s role (server = control plane, agent = worker)";
    };

    serverAddr = mkOption {
      type = types.str;
      default = "";
      description = "URL of the k3s server to join (required for agents and HA servers)";
      example = "https://192.168.50.3:6443";
    };

    token = mkOption {
      type = types.str;
      default = "";
      description = "Shared secret for joining the cluster (tokenFile preferred)";
    };

    tokenFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to file containing the cluster join token";
    };

    agentToken = mkOption {
      type = types.str;
      default = "";
      description = "Shared secret for agent nodes (agentTokenFile preferred)";
    };

    agentTokenFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to file containing the agent join token";
    };

    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Additional CLI flags passed to k3s";
    };

    clusterInit = mkOption {
      type = types.bool;
      default = false;
      description = "Initialize HA with embedded etcd (first server only)";
    };

    disable = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Components to disable (e.g., traefik, servicelb, coredns)";
      example = [ "traefik" "servicelb" ];
    };

    disableAgent = mkOption {
      type = types.bool;
      default = false;
      description = "Run server without kubelet (control plane only)";
    };

    nodeName = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Node name override";
    };

    nodeLabel = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Labels to apply to this node";
      example = [ "role=worker" "zone=us-east-1a" ];
    };

    nodeTaint = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Taints to apply to this node";
      example = [ "dedicated=gpu:NoSchedule" ];
    };

    nodeIP = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "IP address to advertise for this node";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/rancher/k3s";
      description = "k3s data directory";
    };

    clusterCIDR = mkOption {
      type = types.str;
      default = "10.42.0.0/16";
      description = "Pod network CIDR";
    };

    serviceCIDR = mkOption {
      type = types.str;
      default = "10.43.0.0/16";
      description = "Service network CIDR";
    };

    clusterDNS = mkOption {
      type = types.str;
      default = "10.43.0.10";
      description = "Cluster DNS server IP";
    };

    configPath = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to k3s YAML config file";
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to environment file for the systemd service";
    };

    containerdConfigTemplate = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "containerd config template content (TOML)";
    };

    extraKubeletConfig = mkOption {
      type = types.attrs;
      default = {};
      description = "Extra kubelet configuration (merged into kubelet config)";
    };

    extraKubeProxyConfig = mkOption {
      type = types.attrs;
      default = {};
      description = "Extra kube-proxy configuration";
    };

    manifests = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          content = mkOption {
            type = types.str;
            description = "YAML manifest content";
          };
        };
      });
      default = {};
      description = "Auto-deploy manifests (written to k3s manifests dir)";
    };

    images = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Pre-provisioned container images (loaded before k3s starts)";
    };

    firewall = base.mkFirewallOptions;

    kernel = base.mkKernelOptions;

    waitForDNS = base.mkWaitForDNSOptions { description = "k3s"; };

    agent = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable K3s agent mode service (k3s-agent.service)";
      };
    };

    roleConditionPath = mkOption {
      type = types.nullOr (types.submodule {
        options = {
          server = mkOption {
            type = types.str;
            description = "Sentinel file for server mode. k3s.service starts only if this file exists.";
            example = "/var/lib/kindling/server-mode";
          };
          agent = mkOption {
            type = types.str;
            description = "Sentinel file for agent mode. k3s-agent.service starts only if this file exists.";
            example = "/var/lib/kindling/agent-mode";
          };
        };
      });
      default = null;
      description = ''
        Legacy binary (server/agent) sentinel selection. For multi-role
        AMIs (server-init / server-join / agent / agent-gpu / agent-storage
        / agent-ingress) use `roleSentinels` instead.
      '';
    };

    roleSentinels = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = ''
        Multi-role sentinel paths — one per k3s NodeRole. kindling-init
        writes exactly one at boot from userdata; systemd
        ConditionPathExists (OR-semantics via repeated entries) selects
        the matching service. If no sentinel exists (AMI build time),
        no k3s service starts.

        Canonical keys mirror arch-synthesizer k3s::NodeRole::slug():
        "server-init", "server-join", "agent", "agent-gpu",
        "agent-storage", "agent-ingress".

        server-* sentinels activate k3s.service; agent-* sentinels
        activate k3s-agent.service.
      '';
      example = literalExpression ''
        {
          "server-init"    = "/var/lib/kindling/role-server-init";
          "server-join"    = "/var/lib/kindling/role-server-join";
          "agent"          = "/var/lib/kindling/role-agent";
          "agent-gpu"      = "/var/lib/kindling/role-agent-gpu";
          "agent-storage"  = "/var/lib/kindling/role-agent-storage";
          "agent-ingress"  = "/var/lib/kindling/role-agent-ingress";
        }
      '';
    };

    cisHardening = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Master toggle. When true, the submodule's knobs default to
          their CIS-aligned values; user can still override any knob.
        '';
      };

      readOnlyPortDisabled = mkOption {
        type = types.bool;
        default = cfg.cisHardening.enable;
        description = "CIS 4.2.4 — set --kubelet-arg=read-only-port=0";
      };

      anonymousAuthDisabled = mkOption {
        type = types.bool;
        default = cfg.cisHardening.enable;
        description = "CIS 4.2.1 — set --kubelet-arg=anonymous-auth=false";
      };

      authorizationModeWebhook = mkOption {
        type = types.bool;
        default = cfg.cisHardening.enable;
        description = "CIS 4.2.2 — set --kubelet-arg=authorization-mode=Webhook";
      };

      protectKernelDefaults = mkOption {
        type = types.bool;
        default = false;
        description = ''
          CIS 4.2.6 — pass --protect-kernel-defaults=true. Set true at
          CIS Level 2 and FedRAMP. Requires compatible kernel sysctl
          defaults (enforced by base.mkSysctlConfig).
        '';
      };

      makeIptablesUtilChains = mkOption {
        type = types.bool;
        default = cfg.cisHardening.enable;
        description = "CIS 4.2.7 — ensure --kubelet-arg=make-iptables-util-chains=true";
      };
    };

    auditPolicy = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable kube-apiserver audit logging. Server nodes only —
          agents ignore these flags.
        '';
      };

      policyPath = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Path to audit policy YAML on disk (baked into AMI). Passed
          via --kube-apiserver-arg=audit-policy-file.
        '';
      };

      logPath = mkOption {
        type = types.str;
        default = "/var/log/k3s-audit.log";
        description = "kube-apiserver audit log output path";
      };

      logMaxAgeDays = mkOption {
        type = types.ints.unsigned;
        default = 30;
        description = ''
          Maximum retention in days. Compliance floors:
          CIS L2 = 30, FedRAMP Moderate = 90, FedRAMP High = 365.
        '';
      };

      logMaxBackups = mkOption {
        type = types.ints.unsigned;
        default = 10;
        description = "Max rotated audit log files to keep";
      };

      logMaxSizeMb = mkOption {
        type = types.ints.unsigned;
        default = 256;
        description = "Max audit log size in MB before rotation";
      };
    };

    seccompProfile = {
      kind = mkOption {
        type = types.enum [ "unconfined" "runtime_default" "localhost" ];
        default = "unconfined";
        description = ''
          Default seccomp profile for pods on this node. runtime_default
          uses the container runtime's built-in restrictive profile
          (required at CIS Level 2+). localhost points at `path`.
        '';
      };

      path = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Path to seccomp JSON profile (required when kind="localhost").
          Baked into the AMI.
        '';
      };
    };

    # Internal-only — exposes the computed flag lists so unit tests can
    # introspect hardening decisions without forcing package evaluation.
    # Not part of the public API.
    _computed = mkOption {
      type = types.attrs;
      internal = true;
      readOnly = true;
      default = {
        cisKubeletFlags = cisKubeletFlags;
        auditApiserverFlags = auditApiserverFlags;
        hardeningFlags = hardeningFlags;
        serverSentinelPaths = serverSentinelPaths;
        agentSentinelPaths = agentSentinelPaths;
      };
      description = "Read-only computed flag lists for test introspection";
    };

    nvidia = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Configure NVIDIA runtime for containerd";
      };
    };

    gracefulNodeShutdown = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable graceful node shutdown";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # ── Profile defaults (mkDefault so user can override) ──────────────
    (mkIf (activeProfile != null) {
      services.blackmatter.k3s = {
        disable = mkDefault activeProfile.disable;
        extraFlags = mkDefault activeProfile.extraFlags;
        firewall = {
          extraTCPPorts = mkDefault activeProfile.firewallTCP;
          extraUDPPorts = mkDefault activeProfile.firewallUDP;
          trustedInterfaces = mkDefault activeProfile.trustedInterfaces;
        };
        kernel.extraModules = mkDefault activeProfile.kernelModules;
      };
    })

    # ── Core configuration ─────────────────────────────────────────────
    {
      # ── Assertions ────────────────────────────────────────────────────
      assertions = [
        {
          assertion = cfg.role != "agent" || cfg.serverAddr != "";
          message = "services.blackmatter.k3s: agent role requires serverAddr";
        }
        {
          assertion = cfg.role != "agent" || (cfg.tokenFile != null || cfg.token != "");
          message = "services.blackmatter.k3s: agent role requires token or tokenFile";
        }
        {
          # Exactly one sentinel surface — combining legacy + multi-role
          # would produce an AND of conditions (both must match), which
          # is NEVER what the caller wants.
          assertion = cfg.roleConditionPath == null || cfg.roleSentinels == {};
          message = ''
            services.blackmatter.k3s: cannot set both roleConditionPath
            (legacy binary) and roleSentinels (multi-role). Choose one.
          '';
        }
        {
          # Every roleSentinels key must be a known NodeRole slug.
          assertion = all (k: elem k [
            "server-init" "server-join"
            "agent" "agent-gpu" "agent-storage" "agent-ingress"
          ]) (attrNames cfg.roleSentinels);
          message = ''
            services.blackmatter.k3s.roleSentinels: unknown role key.
            Valid: server-init, server-join, agent, agent-gpu,
            agent-storage, agent-ingress.
          '';
        }
        {
          # Audit policy enabled ⇒ policyPath or apiserver will reject.
          assertion = !cfg.auditPolicy.enable || cfg.auditPolicy.policyPath != null;
          message = ''
            services.blackmatter.k3s.auditPolicy.enable = true requires
            auditPolicy.policyPath to be set (kube-apiserver refuses
            audit-log-path without a policy file).
          '';
        }
        {
          # Seccomp localhost profile ⇒ path must be set.
          assertion = cfg.seccompProfile.kind != "localhost" || cfg.seccompProfile.path != null;
          message = ''
            services.blackmatter.k3s.seccompProfile.kind = "localhost"
            requires seccompProfile.path to be set.
          '';
        }
        {
          # If agent-* sentinels are declared, agent.enable must be true.
          assertion = agentSentinelPaths == [] || cfg.agent.enable;
          message = ''
            services.blackmatter.k3s.roleSentinels includes agent-*
            entries but agent.enable is false. Set agent.enable = true
            to activate k3s-agent.service.
          '';
        }
      ];

      # ── Systemd service ──────────────────────────────────────────────
      systemd.services.k3s = {
        description = "k3s - Lightweight Kubernetes";
        after = [ "network-online.target" ]
          ++ optional (cfg.roleConditionPath != null || cfg.roleSentinels != {}) "kindling-init.service";
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];

        # Role sentinel precedence:
        # 1. roleSentinels (multi-role): any server-* sentinel starts
        #    the service (OR via repeated ConditionPathExists lines).
        # 2. roleConditionPath (legacy binary): single server sentinel.
        # 3. Neither set → service starts unconditionally.
        # After=kindling-init.service ensures sentinels are written
        # before conditions are evaluated. Requires= is NOT used so
        # non-kindling systems (no kindling-init.service) still work.
        unitConfig =
          if serverSentinelPaths != []
          then mkRoleSentinelConditions serverSentinelPaths
          else optionalAttrs (cfg.roleConditionPath != null) {
            ConditionPathExists = cfg.roleConditionPath.server;
          };

        path = [ cfg.package ];

        serviceConfig = {
          Type = if cfg.role == "server" then "notify" else "exec";
          ExecStart = "${cfg.package}/bin/k3s ${cfg.role} ${concatStringsSep " " flags}";
          KillMode = "process";
          Delegate = "yes";
          Restart = "always";
          RestartSec = 5;
          LimitNOFILE = 1048576;
          LimitNPROC = "infinity";
          LimitCORE = "infinity";
        }
        // optionalAttrs (cfg.environmentFile != null) {
          EnvironmentFile = cfg.environmentFile;
        }
        // optionalAttrs cfg.waitForDNS.enable {
          ExecStartPre = dnsCheckScript;
        }
        // optionalAttrs cfg.nvidia.enable {
          ExecStartPost = nvidiaPostStartScript;
        };
      };

      # ── K3s agent service ──────────────────────────────────────────
      systemd.services.k3s-agent = mkIf cfg.agent.enable {
        description = "K3s agent — lightweight Kubernetes worker node";
        after = [ "network-online.target" "kindling-init.service" ];
        wants = [ "network-online.target" ];
        conflicts = [ "k3s.service" ];

        # Same sentinel-precedence logic as k3s.service. Multi-role uses
        # the agent-* subset of roleSentinels; legacy uses
        # roleConditionPath.agent. In either case, both services are in
        # wantedBy so systemd attempts both and ConditionPathExists
        # selects the one whose sentinel kindling-init wrote.
        wantedBy = optional
          (cfg.roleConditionPath != null || cfg.roleSentinels != {})
          "multi-user.target";
        unitConfig =
          if agentSentinelPaths != []
          then mkRoleSentinelConditions agentSentinelPaths
          else optionalAttrs (cfg.roleConditionPath != null) {
            ConditionPathExists = cfg.roleConditionPath.agent;
          };

        path = [ cfg.package ];

        serviceConfig = {
          Type = "notify";
          ExecStart = "${cfg.package}/bin/k3s agent"
            + (if cfg.configPath != null then " --config ${cfg.configPath}" else "");
          KillMode = "process";
          Delegate = "yes";
          Restart = "always";
          RestartSec = 5;
          LimitNOFILE = 1048576;
          LimitNPROC = "infinity";
          LimitCORE = "infinity";
          TasksMax = "infinity";
          TimeoutStartSec = 0;
        }
        // optionalAttrs (cfg.environmentFile != null) {
          EnvironmentFile = cfg.environmentFile;
        };
      };

      # ── Pre-provisioned images ───────────────────────────────────────
      systemd.tmpfiles.rules = (
        map (manifest:
          let name = manifest; content = cfg.manifests.${manifest}.content;
          in "C ${cfg.dataDir}/server/manifests/${name}.yaml - - - - ${pkgs.writeText "${name}.yaml" content}"
        ) (attrNames cfg.manifests)
      ) ++ (
        map (img: "C ${cfg.dataDir}/agent/images/${baseNameOf (toString img)} - - - - ${img}")
          cfg.images
      );

      # ── Firewall ─────────────────────────────────────────────────────
      networking.firewall = base.mkFirewallConfig {
        inherit cfg;
        isServer = cfg.role == "server";
      };

      # ── Kernel configuration ─────────────────────────────────────────
      boot.kernelModules = base.mkKernelModulesConfig { inherit cfg; };
      boot.kernel.sysctl = base.mkSysctlConfig { inherit cfg; };
    }
  ]);
}
