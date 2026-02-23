# kubeadm — Kubernetes cluster bootstrap tool
#
# Initializes control planes and joins workers to the cluster.
{ pkgs, k8sSrc, mkGoMonorepoBinary }:

mkGoMonorepoBinary pkgs k8sSrc {
  pname = "kubeadm";
  description = "Kubernetes cluster bootstrap tool";
  homepage = "https://kubernetes.io/docs/reference/setup-tools/kubeadm/";
  completions = { install = true; command = "kubeadm"; };
}
