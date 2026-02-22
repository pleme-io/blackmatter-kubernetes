# Observability & monitoring tools — built from source with our Go toolchain
{ mkGoTool, pkgs }:

{
  thanos = import ./thanos.nix { inherit mkGoTool pkgs; };
  logcli = import ./logcli.nix { inherit mkGoTool pkgs; };
  tempo-cli = import ./tempo-cli.nix { inherit mkGoTool pkgs; };
  mimirtool = import ./mimirtool.nix { inherit mkGoTool pkgs; };
  victoriametrics = import ./victoriametrics.nix { inherit pkgs; };
  coredns = import ./coredns.nix { inherit mkGoTool pkgs; };
  consul = import ./consul.nix { inherit mkGoTool pkgs; };
  kube-state-metrics = import ./kube-state-metrics.nix { inherit pkgs; };
}
