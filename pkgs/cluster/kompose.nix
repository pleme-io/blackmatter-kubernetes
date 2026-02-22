# Kompose — Docker Compose to Kubernetes converter
{ mkGoTool, pkgs }:
let
  version = "1.38.0";
  src = pkgs.fetchFromGitHub {
    owner = "kubernetes";
    repo = "kompose";
    rev = "v${version}";
    hash = "sha256-d2rUkLGU9s2+LTBI3N7WZx1ByDv05DOUq/2OCQViiOM=";
  };
in mkGoTool pkgs {
  pname = "kompose";
  inherit version src;
  vendorHash = "sha256-53G3nkz+uTwpgiZZFfmrv7Wv6d8iVm6xVyRuxjKA5Po=";
  versionLdflags = {
    "github.com/kubernetes/kompose/cmd.GITCOMMIT" = "v${version}";
    "github.com/kubernetes/kompose/cmd.VERSION" = version;
  };
  completions = { install = true; command = "kompose"; };
  description = "Docker Compose to Kubernetes converter";
  homepage = "https://kompose.io/";
}
