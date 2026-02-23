# kube-scheduler — Kubernetes scheduler
#
# Watches for newly created Pods with no assigned node and selects
# a node for them to run on.
{ pkgs, k8sSrc, mkGoMonorepoBinary }:

mkGoMonorepoBinary pkgs k8sSrc {
  pname = "kube-scheduler";
  description = "Kubernetes scheduler";
  homepage = "https://kubernetes.io/docs/reference/command-line-tools-reference/kube-scheduler/";
}
