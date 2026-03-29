# Cluster management tools — built from source with our Go toolchain
{ mkGoTool, pkgs }:

{
  clusterctl = import ./clusterctl.nix { inherit mkGoTool pkgs; };
  talosctl = import ./talosctl.nix { inherit mkGoTool pkgs; };
  vcluster = import ./vcluster.nix { inherit mkGoTool pkgs; };
  crossplane-cli = import ./crossplane-cli.nix { inherit mkGoTool pkgs; };
  kind = import ./kind.nix { inherit mkGoTool pkgs; };
  kompose = import ./kompose.nix { inherit mkGoTool pkgs; };
  kwok = import ./kwok.nix { inherit mkGoTool pkgs; };
  velero = import ./velero.nix { inherit pkgs; };
}
