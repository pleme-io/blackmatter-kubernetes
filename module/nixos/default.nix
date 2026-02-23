# Blackmatter Kubernetes - NixOS module aggregator
{ nixosHelpers, mkGoMonorepoSource }:
{ ... }: {
  imports = [
    (import ./k3s { inherit nixosHelpers; })
    ./kubectl
    (import ./fluxcd { inherit nixosHelpers; })
    (import ./kubernetes { inherit nixosHelpers mkGoMonorepoSource; })
  ];
}
