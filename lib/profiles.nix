# Cluster profiles — pre-canned K8s distribution configurations
#
# Each profile is a validated combination of CNI, ingress, observability,
# security, and storage that maps to concrete k3s flags + additional packages.
#
# Usage: services.blackmatter.k3s.profile = "cilium-standard";
{ lib }:

let
  mkProfile = {
    name,
    description,
    use,
    cni,
    disable ? [],
    extraFlags ? [],
    extraPackages ? [],
    firewallTCP ? [],
    firewallUDP ? [ 8472 ],
    trustedInterfaces ? [ "cni0" "flannel.1" ],
    kernelModules ? [],
    manifests ? {}
  }: {
    inherit name description use cni disable extraFlags
            extraPackages firewallTCP firewallUDP
            trustedInterfaces kernelModules manifests;
  };

in {
  profiles = {
    # ── Flannel profiles ────────────────────────────────────────────────

    flannel-minimal = mkProfile {
      name = "flannel-minimal";
      description = "Bare k3s with flannel CNI, all optional components disabled";
      use = "dev, CI, edge/IoT, learning";
      cni = "flannel";
      disable = [ "traefik" "servicelb" "metrics-server" "local-storage" ];
    };

    flannel-standard = mkProfile {
      name = "flannel-standard";
      description = "K3s with all bundled components enabled";
      use = "dev, staging, small production";
      cni = "flannel";
    };

    flannel-production = mkProfile {
      name = "flannel-production";
      description = "Flannel with full observability and policy enforcement";
      use = "production clusters without advanced networking";
      cni = "flannel";
      extraPackages = [ "kyverno" "trivy" ];
    };

    # ── Calico profiles ─────────────────────────────────────────────────

    calico-standard = mkProfile {
      name = "calico-standard";
      description = "Calico CNI for NetworkPolicy and BGP peering";
      use = "multi-tenant staging/production, hybrid cloud";
      cni = "calico";
      disable = [ "servicelb" ];
      extraFlags = [ "--flannel-backend=none" "--disable-network-policy" ];
      extraPackages = [
        "calico-cni-plugin"
        "calico-kube-controllers"
        "calico-typha"
        "calicoctl"
      ];
      firewallTCP = [ 179 5473 ];      # BGP, typha
      firewallUDP = [ 4789 8472 ];     # VXLAN (calico + flannel fallback)
      trustedInterfaces = [ "cali+" "tunl0" "vxlan.calico" ];
    };

    calico-hardened = mkProfile {
      name = "calico-hardened";
      description = "Calico with full security stack for compliance";
      use = "regulated production, PCI-DSS, SOC2";
      cni = "calico";
      disable = [ "servicelb" ];
      extraFlags = [
        "--flannel-backend=none"
        "--disable-network-policy"
        "--protect-kernel-defaults"
      ];
      extraPackages = [
        "calico-cni-plugin"
        "calico-kube-controllers"
        "calico-typha"
        "calicoctl"
        "kyverno"
        "trivy"
        "falcoctl"
        "kubescape"
        "cosign"
      ];
      firewallTCP = [ 179 5473 ];
      firewallUDP = [ 4789 8472 ];
      trustedInterfaces = [ "cali+" "tunl0" "vxlan.calico" ];
    };

    # ── Cilium profiles ─────────────────────────────────────────────────

    cilium-standard = mkProfile {
      name = "cilium-standard";
      description = "Cilium eBPF CNI replacing kube-proxy";
      use = "production with eBPF performance and observability";
      cni = "cilium";
      disable = [ "servicelb" ];
      extraFlags = [
        "--flannel-backend=none"
        "--disable-network-policy"
        "--disable-kube-proxy"
      ];
      extraPackages = [ "cilium-cli" "hubble" ];
      firewallTCP = [ 4240 4244 ];     # health, hubble
      firewallUDP = [ 8472 ];          # VXLAN
      trustedInterfaces = [ "cilium_host" "cilium_net" "cilium_vxlan" "lxc+" ];
      kernelModules = [ "ip_tables" "xt_socket" "xt_mark" "xt_CT" ];
    };

    cilium-mesh = mkProfile {
      name = "cilium-mesh";
      description = "Cilium with service mesh and Hubble observability";
      use = "microservices production, zero-trust networking";
      cni = "cilium";
      disable = [ "traefik" "servicelb" ];
      extraFlags = [
        "--flannel-backend=none"
        "--disable-network-policy"
        "--disable-kube-proxy"
      ];
      extraPackages = [ "cilium-cli" "hubble" ];
      firewallTCP = [ 4240 4244 ];
      firewallUDP = [ 8472 ];
      trustedInterfaces = [ "cilium_host" "cilium_net" "cilium_vxlan" "lxc+" ];
      kernelModules = [ "ip_tables" "xt_socket" "xt_mark" "xt_CT" ];
    };

    # ── Service mesh profiles ───────────────────────────────────────────

    istio-mesh = mkProfile {
      name = "istio-mesh";
      description = "Istio service mesh on flannel for mTLS-everywhere";
      use = "enterprise service mesh, advanced traffic management";
      cni = "flannel";
      disable = [ "traefik" ];
      extraPackages = [ "istioctl" ];
      firewallTCP = [ 15012 15014 15017 ];  # istiod xDS, monitoring, webhook
    };
  };

  defaultProfile = "flannel-standard";
}
