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
{ nixosHelpers, mkGoMonorepoSource }:

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
  k8sPkgs = import ../../../pkgs/kubernetes { inherit pkgs mkGoMonorepoSource; };

  # Select packages based on distribution track
  trackPackages =
    if cfg.distribution == "1.35"
    then k8sPkgs.track_1_35
    else k8sPkgs.track_1_34;

  # Kernel modules needed by vanilla k8s
  baseKernelModules = [ "overlay" "br_netfilter" ];
  ipvsModules = [ "ip_vs" "ip_vs_rr" "ip_vs_wrr" "ip_vs_sh" ];

  # Base sysctl settings
  baseSysctl = {
    "net.bridge.bridge-nf-call-iptables" = 1;
    "net.bridge.bridge-nf-call-ip6tables" = 1;
    "net.ipv4.ip_forward" = 1;
  };

  # DNS pre-check script (shared with k3s pattern)
  dnsCheckScript = pkgs.writeShellScript "k8s-dns-check" ''
    echo "Waiting for network and DNS to be ready..."
    for i in $(seq 1 ${toString cfg.waitForDNS.timeout}); do
      if ${pkgs.dnsutils}/bin/nslookup registry-1.docker.io >/dev/null 2>&1; then
        echo "DNS is ready!"
        exit 0
      fi
      echo "Waiting for DNS... ($i/${toString cfg.waitForDNS.timeout})"
      sleep 2
    done
    echo "DNS check complete, proceeding with Kubernetes startup"
  '';

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
      type = types.enum [ "1.34" "1.35" ];
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
        description = "Wait for DNS before starting kubelet";
      };

      timeout = mkOption {
        type = types.int;
        default = 30;
        description = "Number of retries (2s interval) for DNS check";
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
      networking.firewall = mkIf cfg.firewall.enable {
        allowedTCPPorts =
          optional (cfg.role == "control-plane") cfg.firewall.apiServerPort
          ++ [ 10250 ]  # kubelet
          ++ cfg.firewall.extraTCPPorts;

        allowedUDPPorts = cfg.firewall.extraUDPPorts;
        trustedInterfaces = cfg.firewall.trustedInterfaces;
      };

      # ── Kernel configuration ───────────────────────────────────────
      boot.kernelModules = mkIf cfg.kernel.enable (
        baseKernelModules ++ ipvsModules ++ cfg.kernel.extraModules
      );

      boot.kernel.sysctl = mkIf cfg.kernel.enable baseSysctl;

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
