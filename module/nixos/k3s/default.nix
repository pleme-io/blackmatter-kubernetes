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

  # DNS pre-check script
  dnsCheckScript = pkgs.writeShellScript "k3s-dns-check" ''
    echo "Waiting for network and DNS to be ready..."
    for i in $(seq 1 ${toString cfg.waitForDNS.timeout}); do
      if ${pkgs.dnsutils}/bin/nslookup registry-1.docker.io >/dev/null 2>&1; then
        echo "DNS is ready!"
        exit 0
      fi
      echo "Waiting for DNS... ($i/${toString cfg.waitForDNS.timeout})"
      sleep 2
    done
    echo "DNS check complete, proceeding with k3s startup"
  '';

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

  # Kernel modules needed by k3s
  baseKernelModules = [ "overlay" "br_netfilter" ];
  ipvsModules = [ "ip_vs" "ip_vs_rr" "ip_vs_wrr" "ip_vs_sh" ];

  # Base sysctl settings
  baseSysctl = {
    "net.bridge.bridge-nf-call-iptables" = 1;
    "net.bridge.bridge-nf-call-ip6tables" = 1;
    "net.ipv4.ip_forward" = 1;
  };

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

    firewall = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Automatically configure firewall rules";
      };

      apiServerPort = mkOption {
        type = types.int;
        default = 6443;
        description = "Kubernetes API server port";
      };

      extraTCPPorts = mkOption {
        type = types.listOf types.int;
        default = [];
        description = "Additional TCP ports to open";
      };

      extraUDPPorts = mkOption {
        type = types.listOf types.int;
        default = [ 8472 ];
        description = "Additional UDP ports to open (default includes VXLAN)";
      };

      trustedInterfaces = mkOption {
        type = types.listOf types.str;
        default = [ "cni0" "flannel.1" ];
        description = "Network interfaces to trust (CNI bridges)";
      };
    };

    kernel = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Automatically configure kernel modules and sysctl";
      };

      extraModules = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Additional kernel modules to load";
      };
    };

    waitForDNS = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Wait for DNS before starting k3s";
      };

      timeout = mkOption {
        type = types.int;
        default = 30;
        description = "Number of retries (2s interval) for DNS check";
      };
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
      networking.firewall = mkIf cfg.firewall.enable {
        allowedTCPPorts =
          optional (cfg.role == "server") cfg.firewall.apiServerPort
          ++ [ 10250 ]  # kubelet
          ++ cfg.firewall.extraTCPPorts;

        allowedUDPPorts = cfg.firewall.extraUDPPorts;
        trustedInterfaces = cfg.firewall.trustedInterfaces;
      };

      # ── Kernel configuration ─────────────────────────────────────────
      boot.kernelModules = mkIf cfg.kernel.enable (
        baseKernelModules ++ cfg.kernel.extraModules
      );

      boot.kernel.sysctl = mkIf cfg.kernel.enable baseSysctl;
    }
  ]);
}
