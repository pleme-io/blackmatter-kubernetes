# kube-controller-manager — Kubernetes controller manager
#
# Runs controller loops that regulate cluster state (node, job, endpoint,
# service account, replication controllers, etc.).
{ pkgs, k8sSrc, mkGoMonorepoBinary }:

mkGoMonorepoBinary pkgs k8sSrc {
  pname = "kube-controller-manager";
  description = "Kubernetes controller manager";
  homepage = "https://kubernetes.io/docs/reference/command-line-tools-reference/kube-controller-manager/";
}
