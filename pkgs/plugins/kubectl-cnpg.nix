# kubectl-cnpg — CloudNativePG kubectl plugin
{ mkGoTool, pkgs }:
let
  version = "1.28.1";
  src = pkgs.fetchFromGitHub {
    owner = "cloudnative-pg";
    repo = "cloudnative-pg";
    rev = "v${version}";
    hash = "sha256-9NfjrVF0OtDLaGD5PPFSZcI8V3Vy/yOTm/JwnE3kMZE=";
  };
in mkGoTool pkgs {
  pname = "kubectl-cnpg";
  inherit version src;
  vendorHash = "sha256-QNtKtHTxOgm6EbOSvA2iUE0hjltwTBNkA1mIC3N+AbM=";
  subPackages = [ "cmd/kubectl-cnpg" ];
  description = "Plugin for kubectl to manage CloudNativePG clusters";
  homepage = "https://cloudnative-pg.io/";
}
