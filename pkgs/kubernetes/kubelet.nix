# kubelet — Kubernetes node agent
#
# Runs on every node. Manages pods and containers via the container runtime.
# Requires systemd and conntrack-tools at runtime.
{ pkgs, k8sSrc, mkGoMonorepoBinary }:

mkGoMonorepoBinary pkgs k8sSrc {
  pname = "kubelet";
  description = "Kubernetes node agent";
  homepage = "https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/";
}
