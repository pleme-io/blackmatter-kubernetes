# kube-apiserver — Kubernetes API server
#
# Stateless component that validates and configures data for API objects.
# Serves as the front-end for the cluster's shared state (etcd is separate).
{ pkgs, k8sSrc, mkGoMonorepoBinary }:

mkGoMonorepoBinary pkgs k8sSrc {
  pname = "kube-apiserver";
  description = "Kubernetes API server";
  homepage = "https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/";
}
