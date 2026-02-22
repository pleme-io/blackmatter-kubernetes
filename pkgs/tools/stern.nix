# Stern — Multi-pod log tailing for Kubernetes
{ mkGoTool, pkgs }:

let
  version = "1.33.1";
  src = pkgs.fetchFromGitHub {
    owner = "stern";
    repo = "stern";
    rev = "v${version}";
    hash = "sha256-2GCUPmeSbRg1TE5pD42BiHUwzxqS+9FV9ZYIaZKwNWo=";
  };
in mkGoTool pkgs {
  pname = "stern";
  inherit version src;
  vendorHash = "sha256-xDkYW542V2M9CvjNBFojRw4KAhcxvlBPVJCndlF+MKw=";
  subPackages = [ "." ];
  versionLdflags = {
    "github.com/stern/stern/cmd.version" = version;
  };
  completions = { install = true; command = "stern"; };
  description = "Multi-pod and multi-container log tailing for Kubernetes";
  homepage = "https://github.com/stern/stern";
}
