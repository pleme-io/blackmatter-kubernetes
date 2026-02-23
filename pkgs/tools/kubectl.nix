# Kubectl — Kubernetes CLI
#
# kubectl lives in the Kubernetes monorepo. Uses the shared source factory
# to stay in sync with the control plane binaries. Version ldflags are
# replicated from hack/lib/version.sh.
{ pkgs, mkGoMonorepoSource }:

let
  lib = pkgs.lib;
  mkSource = import ../kubernetes/source.nix { inherit mkGoMonorepoSource pkgs; };
  versions = import ../../lib/versions/kubernetes-1.35.nix;
  hashes = import ../kubernetes/versions/1_35.nix;
  k8sSrc = mkSource { inherit versions hashes; };
in pkgs.buildGoModule {
  pname = "kubectl";
  inherit (k8sSrc) version src;

  vendorHash = null; # vendored in-tree

  subPackages = [ "cmd/kubectl" ];

  ldflags = k8sSrc.ldflags;

  doCheck = false;

  nativeBuildInputs = [ pkgs.installShellFiles ];

  postInstall = ''
    installShellCompletion --cmd kubectl \
      --bash <($out/bin/kubectl completion bash) \
      --zsh <($out/bin/kubectl completion zsh) \
      --fish <($out/bin/kubectl completion fish)
  '';

  meta = {
    description = "Kubernetes CLI";
    homepage = "https://kubernetes.io/docs/reference/kubectl/";
    license = lib.licenses.asl20;
    mainProgram = "kubectl";
    platforms = lib.platforms.unix;
  };
}
