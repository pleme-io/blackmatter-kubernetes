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
    ++ cfg.extraFlags;

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
    ++ cfg.extraFlags;

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
      type = types.nullOr types.str;
      default = null;
      description = ''
        Path to a sentinel file that determines server vs agent mode at boot.
        When set, k3s.service only starts if this file EXISTS (server mode),
        and k3s-agent.service only starts if it does NOT exist (agent mode).
        The init service (e.g. kindling-init) creates or removes this file
        before either K3s service starts, making role selection race-free
        via systemd ConditionPathExists.
      '';
      example = "/var/lib/kindling/server-mode";
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
      ];

      # ── Systemd service ──────────────────────────────────────────────
      systemd.services.k3s = {
        description = "k3s - Lightweight Kubernetes";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];

        # When roleConditionPath is set, only start if the sentinel file
        # exists (server mode). Condition is evaluated at execution time,
        # AFTER all ordering dependencies (Before=/After=) are satisfied.
        unitConfig = optionalAttrs (cfg.roleConditionPath != null) {
          ConditionPathExists = cfg.roleConditionPath;
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

        # When roleConditionPath is set, both services are in wantedBy and
        # ConditionPathExists selects exactly one at boot — no runtime
        # systemctl commands needed.
        wantedBy = optional (cfg.roleConditionPath != null) "multi-user.target";
        unitConfig = optionalAttrs (cfg.roleConditionPath != null) {
          ConditionPathExists = "!${cfg.roleConditionPath}";
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
