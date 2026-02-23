# kube-proxy — Kubernetes network proxy
#
# Maintains network rules on nodes for Service abstraction.
# Needs iptables/nftables and conntrack at runtime.
# Not needed when using Cilium in kube-proxy replacement mode.
{ pkgs, k8sSrc }:

pkgs.buildGoModule {
  pname = "kube-proxy";
  inherit (k8sSrc) version src;

  vendorHash = null;
  subPackages = [ "cmd/kube-proxy" ];
  ldflags = k8sSrc.ldflags;
  doCheck = false;

  meta = {
    description = "Kubernetes network proxy";
    homepage = "https://kubernetes.io/docs/reference/command-line-tools-reference/kube-proxy/";
    license = pkgs.lib.licenses.asl20;
    mainProgram = "kube-proxy";
    platforms = pkgs.lib.platforms.linux;
  };
}
