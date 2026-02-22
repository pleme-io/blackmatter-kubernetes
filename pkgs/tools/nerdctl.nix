# Nerdctl — Docker-compatible CLI for containerd
{ mkGoTool, pkgs }:
let
  version = "2.2.1";
  src = pkgs.fetchFromGitHub {
    owner = "containerd";
    repo = "nerdctl";
    rev = "v${version}";
    hash = "sha256-KD7wXU3RSWJWLSOd7ZFEAfETezb/5ijWPyxXMjIeX6E=";
  };
in mkGoTool pkgs {
  pname = "nerdctl";
  inherit version src;
  vendorHash = "sha256-vq4NpKS8JvsOGK25fksjsqdNS6H/B1VPqTYwqYv2blc=";
  subPackages = [ "cmd/nerdctl" ];
  versionLdflags = {
    "github.com/containerd/nerdctl/v2/pkg/version.Version" = "v${version}";
  };
  completions = { install = true; command = "nerdctl"; };
  platforms = pkgs.lib.platforms.linux;
  description = "Docker-compatible CLI for containerd";
  homepage = "https://github.com/containerd/nerdctl";
}
