# Shared Kubernetes base configuration
#
# Constants, option definitions, and config fragments shared between
# k3s and vanilla k8s NixOS modules. Eliminates duplication of kernel
# modules, sysctl, firewall rules, DNS checks, and option schemas.
#
# Usage in a NixOS module:
#   let base = import ../../../lib/kubernetes-base.nix { inherit lib pkgs; };
{ lib, pkgs }:

with lib;

{
  # ============================================================================
  # SHARED CONSTANTS
  # ============================================================================

  # Kernel modules required by all Kubernetes distributions
  baseKernelModules = [ "overlay" "br_netfilter" ];

  # IPVS modules for kube-proxy IPVS mode
  ipvsModules = [ "ip_vs" "ip_vs_rr" "ip_vs_wrr" "ip_vs_sh" ];

  # Base sysctl settings required for pod networking
  baseSysctl = {
    "net.bridge.bridge-nf-call-iptables" = 1;
    "net.bridge.bridge-nf-call-ip6tables" = 1;
    "net.ipv4.ip_forward" = 1;
  };

  # ============================================================================
  # DNS PRE-CHECK SCRIPT FACTORY
  # ============================================================================

  # Generate a DNS pre-check script with a customizable service name.
  # Waits for DNS to resolve registry-1.docker.io before proceeding.
  mkDnsCheckScript = { name, timeout }: pkgs.writeShellScript "${name}-dns-check" ''
    echo "Waiting for network and DNS to be ready..."
    for i in $(seq 1 ${toString timeout}); do
      if ${pkgs.dnsutils}/bin/nslookup registry-1.docker.io >/dev/null 2>&1; then
        echo "DNS is ready!"
        exit 0
      fi
      echo "Waiting for DNS... ($i/${toString timeout})"
      sleep 2
    done
    echo "DNS check complete, proceeding with ${name} startup"
  '';

  # ============================================================================
  # SHARED OPTION DEFINITIONS
  # ============================================================================
  # Reusable NixOS module options for firewall, kernel, and DNS wait.

  mkFirewallOptions = {
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

  mkKernelOptions = {
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

  mkWaitForDNSOptions = { description ? "Kubernetes" }: {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Wait for DNS before starting ${description}";
    };

    timeout = mkOption {
      type = types.int;
      default = 30;
      description = "Number of retries (2s interval) for DNS check";
    };
  };

  # ============================================================================
  # SHARED CONFIG FRAGMENTS
  # ============================================================================

  # Generate firewall config from a module's cfg.
  # isServer: whether this node runs the API server (controls apiServerPort)
  mkFirewallConfig = { cfg, isServer }: mkIf cfg.firewall.enable {
    allowedTCPPorts =
      optional isServer cfg.firewall.apiServerPort
      ++ [ 10250 ]  # kubelet
      ++ cfg.firewall.extraTCPPorts;

    allowedUDPPorts = cfg.firewall.extraUDPPorts;
    trustedInterfaces = cfg.firewall.trustedInterfaces;
  };

  # Generate kernel module config.
  # extraBaseModules: additional modules always loaded (e.g., ipvsModules for vanilla k8s)
  mkKernelModulesConfig = { cfg, extraBaseModules ? [] }:
    mkIf cfg.kernel.enable (
      [ "overlay" "br_netfilter" ] ++ extraBaseModules ++ cfg.kernel.extraModules
    );

  # Generate sysctl config.
  mkSysctlConfig = { cfg }:
    mkIf cfg.kernel.enable {
      "net.bridge.bridge-nf-call-iptables" = 1;
      "net.bridge.bridge-nf-call-ip6tables" = 1;
      "net.ipv4.ip_forward" = 1;
    };
}
