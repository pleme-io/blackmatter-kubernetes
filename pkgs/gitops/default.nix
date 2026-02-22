# GitOps & CD tools — built from source with our Go toolchain
{ mkGoTool, pkgs }:

{
  argocd = import ./argocd.nix { inherit mkGoTool pkgs; };
  tektoncd-cli = import ./tektoncd-cli.nix { inherit mkGoTool pkgs; };
  argo-rollouts = import ./argo-rollouts.nix { inherit mkGoTool pkgs; };
  timoni = import ./timoni.nix { inherit mkGoTool pkgs; };
  kapp = import ./kapp.nix { inherit mkGoTool pkgs; };
}
