# BuildKit — Concurrent, cache-efficient container image builder
{ mkGoTool, pkgs }:
let
  version = "0.27.1";
  src = pkgs.fetchFromGitHub {
    owner = "moby";
    repo = "buildkit";
    rev = "v${version}";
    hash = "sha256-vMSg5bYFkdWrdjexx/3kwyyingS5gqMcw5/JQ4RxDeU=";
  };
in mkGoTool pkgs {
  pname = "buildkit";
  inherit version src;
  vendorHash = null;
  subPackages = [ "cmd/buildctl" ];
  versionLdflags = {
    "github.com/moby/buildkit/version.Version" = "v${version}";
  };
  description = "Concurrent, cache-efficient, Dockerfile-agnostic builder toolkit";
  homepage = "https://github.com/moby/buildkit";
}
