# Flannel — CNI overlay network daemon
{ mkGoTool, pkgs }:

let
  version = "0.28.1";
  src = pkgs.fetchFromGitHub {
    owner = "flannel-io";
    repo = "flannel";
    rev = "v${version}";
    sha256 = "sha256-kYUy7Dije5Ba2//bosarDO3UgxKFi7YXrH2RhV2NqPA=";
  };
in mkGoTool pkgs {
  pname = "flannel";
  inherit version src;
  vendorHash = "sha256-Iwfmi9poxubI+l847BYTpE8lpeIHTPwUt8ulfqMGTfQ=";
  versionLdflags = {
    "github.com/flannel-io/flannel/pkg/version.Version" = "v${version}";
  };
  platforms = pkgs.lib.platforms.linux;
  description = "CNI overlay network for Kubernetes";
  homepage = "https://github.com/flannel-io/flannel";
}
