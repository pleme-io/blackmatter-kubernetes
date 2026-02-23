# K8s Tools — built from source with our Go toolchain
#
# Each tool is a standalone buildGoModule derivation using substrate's
# mkGoTool helper. All tools use the Go overlay from substrate for
# consistent toolchain versions.
#
# Usage:
#   tools = import ./pkgs/tools { inherit mkGoTool pkgs; };
#   # tools.helm, tools.k9s, tools.stern, etc.
{ mkGoTool, pkgs }:

{
  helm = import ./helm.nix { inherit mkGoTool pkgs; };
  k9s = import ./k9s.nix { inherit mkGoTool pkgs; };
  fluxcd = import ./fluxcd.nix { inherit mkGoTool pkgs; };
  kubectx = import ./kubectx.nix { inherit mkGoTool pkgs; };
  stern = import ./stern.nix { inherit mkGoTool pkgs; };
  kubecolor = import ./kubecolor.nix { inherit mkGoTool pkgs; };
  kube-score = import ./kube-score.nix { inherit mkGoTool pkgs; };
  kubectl-tree = import ./kubectl-tree.nix { inherit mkGoTool pkgs; };
  kustomize = import ./kustomize.nix { inherit mkGoTool pkgs; };
  cilium-cli = import ./cilium-cli.nix { inherit mkGoTool pkgs; };
  calicoctl = import ./calicoctl.nix { inherit mkGoTool pkgs; };

  # Container/image tools
  crane = import ./crane.nix { inherit mkGoTool pkgs; };
  nerdctl = import ./nerdctl.nix { inherit mkGoTool pkgs; };
  buildkit = import ./buildkit.nix { inherit mkGoTool pkgs; };
  ko = import ./ko.nix { inherit mkGoTool pkgs; };

  # Helm ecosystem
  helmfile = import ./helmfile.nix { inherit mkGoTool pkgs; };
  helm-diff = import ./helm-diff.nix { inherit mkGoTool pkgs; };
  helm-docs = import ./helm-docs.nix { inherit mkGoTool pkgs; };

  # Infrastructure
  etcd = import ./etcd.nix { inherit pkgs; };

  # Development
  kubebuilder = import ./kubebuilder.nix { inherit pkgs; };
  operator-sdk = import ./operator-sdk.nix { inherit pkgs; };
}
