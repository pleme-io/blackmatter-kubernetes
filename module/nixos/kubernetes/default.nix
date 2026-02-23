# NixOS vanilla Kubernetes module — services.blackmatter.kubernetes
#
# Full vanilla Kubernetes with kubeadm, matching the k3s module's profile
# system, version tracks, and option patterns. Unlike k3s (single binary),
# each component runs as a separate systemd service.
#
# Usage:
#   services.blackmatter.kubernetes = {
#     enable = true;
#     role = "control-plane";
#     distribution = "1.34";
#     profile = "flannel-standard";
#   };
{ nixosHelpers, mkGoMonorepoSource, mkGoMonorepoBinary }:

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.blackmatter.kubernetes;

  profileDefs = import ../../../lib/profiles.nix { inherit lib; };
  profileNames = attrNames profileDefs.profiles;
  activeProfile =
    if cfg.profile != null
    then profileDefs.profiles.${cfg.profile}
    else null;

  versionRegistry = import ../../../lib/versions;
  k8sPkgs = import ../../../pkgs/kubernetes { inherit pkgs mkGoMonorepoSource mkGoMonorepoBinary; };

  # Select packages based on distribution track
  trackSuffix = builtins.replaceStrings ["."] ["_"] cfg.distribution;
  trackPackages = k8sPkgs.${"track_${trackSuffix}"};

  # Shared Kubernetes base config (kernel modules, sysctl, DNS check, options)
  base = import ../../../lib/kubernetes-base.nix { inherit lib pkgs; };

  dnsCheckScript = base.mkDnsCheckScript {
    name = "k8s";
    timeout = cfg.waitForDNS.timeout;
  };

in {
  imports = [
    ./control-plane.nix
    ./kubelet.nix
    ./etcd.nix
    ./kubeadm.nix
    ./certs.nix
  ];

  options.services.blackmatter.kubernetes = {
    enable = mkEnableOption "vanilla Kubernetes (kubeadm-managed)";

    profile = mkOption {
      type = types.nullOr (types.enum profileNames);
      default = null;
      description = ''
        Cluster profile — pre-canned configuration for CNI, firewall, and
        kernel modules. Same profiles as k3s for consistency.

        Available profiles: ${concatStringsSep ", " profileNames}
      '';
      example = "cilium-standard";
    };

    distribution = mkOption {
      type = types.enum [ "1.30" "1.31" "1.32" "1.33" "1.34" "1.35" ];
      default = "1.34";
      description = "Kubernetes version track (same tracks as k3s)";
    };

    role = mkOption {
      type = types.enum [ "control-plane" "worker" ];
      default = "control-plane";
      description = "Node role (control-plane = k3s server, worker = k3s agent)";
    };

    # Expose resolved version constants for sub-modules
    versions = mkOption {
      type = types.attrs;
      default = versionRegistry.${cfg.distribution};
      internal = true;
      description = "Resolved version constants from the shared registry";
    };

    # Expose resolved packages for sub-modules
    packages = mkOption {
      type = types.attrs;
      default = trackPackages;
      internal = true;
      description = "Resolved package set for the selected distribution track";
    };

    serverAddr = mkOption {
      type = types.str;
      default = "";
      description = "Control plane endpoint (required for workers and HA join)";
      example = "192.168.50.3:6443";
    };

    token = mkOption {
      type = types.str;
      default = "";
      description = "Bootstrap token for joining the cluster (tokenFile preferred)";
    };

    tokenFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to file containing the bootstrap token";
    };

    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Additional flags passed to kubelet";
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
      default = "/var/lib/kubernetes";
      description = "Kubernetes data directory";
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

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to environment file for systemd services";
    };

    containerRuntime = {
      containerdConfigTemplate = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Custom containerd config content (TOML)";
      };

      nvidia.enable = mkOption {
        type = types.bool;
        default = false;
        description = "Configure NVIDIA runtime for containerd";
      };
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
      description = "Auto-deploy manifests (applied after cluster init)";
    };

    firewall = base.mkFirewallOptions;

    kernel = base.mkKernelOptions;

    waitForDNS = base.mkWaitForDNSOptions { description = "kubelet"; };

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
      services.blackmatter.kubernetes = {
        extraFlags = mkDefault activeProfile.extraFlags;
        controlPlane.disableKubeProxy = mkDefault activeProfile.disableKubeProxy;
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
      # ── Assertions ──────────────────────────────────────────────────
      assertions = [
        {
          assertion = cfg.role != "worker" || cfg.serverAddr != "";
          message = "services.blackmatter.kubernetes: worker role requires serverAddr";
        }
        {
          assertion = cfg.role != "worker" || (cfg.tokenFile != null || cfg.token != "");
          message = "services.blackmatter.kubernetes: worker role requires token or tokenFile";
        }
      ];

      # ── Firewall ───────────────────────────────────────────────────
      networking.firewall = base.mkFirewallConfig {
        inherit cfg;
        isServer = cfg.role == "control-plane";
      };

      # ── Kernel configuration ───────────────────────────────────────
      boot.kernelModules = base.mkKernelModulesConfig {
        inherit cfg;
        extraBaseModules = base.ipvsModules;
      };
      boot.kernel.sysctl = base.mkSysctlConfig { inherit cfg; };

      # ── System packages ────────────────────────────────────────────
      environment.systemPackages = [
        cfg.packages.kubelet
        cfg.packages.crictl
        (pkgs.blackmatter-kubectl or pkgs.kubectl)
      ];

      # ── Data directories ───────────────────────────────────────────
      systemd.tmpfiles.rules = [
        "d ${cfg.dataDir} 0755 root root -"
        "d ${cfg.dataDir}/pki 0700 root root -"
      ];
    }
  ]);
}
