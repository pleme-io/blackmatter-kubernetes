# kubectl plugins — built from source with our Go toolchain
{ mkGoTool, pkgs }:

{
  popeye = import ./popeye.nix { inherit mkGoTool pkgs; };
  kubent = import ./kubent.nix { inherit mkGoTool pkgs; };
  pluto = import ./pluto.nix { inherit mkGoTool pkgs; };
  kor = import ./kor.nix { inherit mkGoTool pkgs; };
  kube-capacity = import ./kube-capacity.nix { inherit mkGoTool pkgs; };
  kubectl-neat = import ./kubectl-neat.nix { inherit mkGoTool pkgs; };
  kubectl-images = import ./kubectl-images.nix { inherit mkGoTool pkgs; };
  krew = import ./krew.nix { inherit pkgs; };
  kubectl-ktop = import ./kubectl-ktop.nix { inherit mkGoTool pkgs; };
  kubeshark = import ./kubeshark.nix { inherit mkGoTool pkgs; };
  kubectl-cnpg = import ./kubectl-cnpg.nix { inherit mkGoTool pkgs; };
  kubevirt = import ./kubevirt.nix { inherit pkgs; };
}
