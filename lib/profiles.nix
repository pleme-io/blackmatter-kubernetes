# Cluster profiles — pre-canned K8s distribution configurations
#
# Each profile is a validated combination of CNI, ingress, observability,
# security, and storage. Consumed by both k3s and vanilla k8s modules:
#
#   k3s:  uses disable (--disable flags), extraFlags, firewall, kernelModules
#   k8s:  uses disableKubeProxy, firewall, kernelModules, extraPackages
#         (disable/extraFlags are k3s-specific, ignored by k8s module)
#
# Usage:
#   services.blackmatter.k3s.profile = "cilium-standard";
#   services.blackmatter.kubernetes.profile = "cilium-standard";
{ lib }:

let
  mkProfile = {
    name,
    description,
    use,
    cni,
    disable ? [],
    disableKubeProxy ? false,
    extraFlags ? [],
    extraPackages ? [],
    firewallTCP ? [],
    firewallUDP ? [ 8472 ],
    trustedInterfaces ? [ "cni0" "flannel.1" ],
    kernelModules ? [],
    manifests ? {}
  }: {
    inherit name description use cni disable disableKubeProxy extraFlags
            extraPackages firewallTCP firewallUDP
            trustedInterfaces kernelModules manifests;
  };

in {
  profiles = {
    # ── Flannel profiles ────────────────────────────────────────────────

    flannel-minimal = mkProfile {
      name = "flannel-minimal";
      description = "Bare cluster with flannel CNI, minimal components";
      use = "dev, CI, edge/IoT, learning";
      cni = "flannel";
      disable = [ "traefik" "servicelb" "metrics-server" "local-storage" ];
    };

    flannel-standard = mkProfile {
      name = "flannel-standard";
      description = "Standard cluster with flannel CNI and bundled components";
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
      disableKubeProxy = true;
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
      disableKubeProxy = true;
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
