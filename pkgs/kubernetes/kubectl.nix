# kubectl — Kubernetes CLI
#
# kubectl lives in the Kubernetes monorepo. Uses mkGoMonorepoBinary to stay
# in sync with the other control plane binaries (kubelet, kubeadm, etc.).
# Cross-platform (macOS + Linux) unlike the other monorepo binaries.
{ pkgs, k8sSrc, mkGoMonorepoBinary }:

mkGoMonorepoBinary pkgs k8sSrc {
  pname = "kubectl";
  description = "Kubernetes CLI";
  homepage = "https://kubernetes.io/docs/reference/kubectl/";
  completions = { install = true; command = "kubectl"; };
  platforms = pkgs.lib.platforms.unix;
}
