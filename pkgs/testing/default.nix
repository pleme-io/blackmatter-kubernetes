# Load testing & benchmarking tools — built from source with our Go toolchain
{ mkGoTool, pkgs }:

{
  k6 = import ./k6.nix { inherit mkGoTool pkgs; };
  vegeta = import ./vegeta.nix { inherit mkGoTool pkgs; };
  hey = import ./hey.nix { inherit mkGoTool pkgs; };
  fortio = import ./fortio.nix { inherit mkGoTool pkgs; };
}
