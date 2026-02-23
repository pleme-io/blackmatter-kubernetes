# kube-proxy — Kubernetes network proxy
#
# Maintains network rules on nodes for Service abstraction.
# Needs iptables/nftables and conntrack at runtime.
# Not needed when using Cilium in kube-proxy replacement mode.
{ pkgs, k8sSrc, mkGoMonorepoBinary }:

mkGoMonorepoBinary pkgs k8sSrc {
  pname = "kube-proxy";
  description = "Kubernetes network proxy";
  homepage = "https://kubernetes.io/docs/reference/command-line-tools-reference/kube-proxy/";
}
