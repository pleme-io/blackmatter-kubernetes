# Blackmatter Kubernetes - NixOS module aggregator
{ nixosHelpers }:
{ ... }: {
  imports = [
    (import ./k3s { inherit nixosHelpers; })
    ./kubectl
  ];
}
