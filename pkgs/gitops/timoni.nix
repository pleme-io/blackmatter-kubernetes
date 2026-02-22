# Timoni — CUE-based Kubernetes package manager
{ mkGoTool, pkgs }:
let
  version = "0.25.2";
  src = pkgs.fetchFromGitHub {
    owner = "stefanprodan";
    repo = "timoni";
    rev = "v${version}";
    hash = "sha256-u59+FGBURP3p1zosZU+6IfCZMHl4plrf/8/FUUgj/qw=";
  };
in mkGoTool pkgs {
  pname = "timoni";
  inherit version src;
  vendorHash = "sha256-bWhXhZJHdiWY/Yz0l2VAPKJrMVb9XbvVEGPNZIQtvFQ=";
  subPackages = [ "cmd/timoni" ];
  versionLdflags = {
    "main.VERSION" = version;
  };
  completions = { install = true; command = "timoni"; };
  description = "CUE-based Kubernetes package manager (by FluxCD author)";
  homepage = "https://timoni.sh/";
}
