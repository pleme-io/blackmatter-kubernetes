# Pluto — Find deprecated Kubernetes apiVersions
{ mkGoTool, pkgs }:
let
  version = "5.22.7";
  src = pkgs.fetchFromGitHub {
    owner = "FairwindsOps";
    repo = "pluto";
    rev = "v${version}";
    hash = "sha256-lB8xMkKCnQYMtwvYXbCwSsh30nbpQ/2Pl8dHA1R3bQg=";
  };
in mkGoTool pkgs {
  pname = "pluto";
  inherit version src;
  vendorHash = "sha256-PVax9C1tSlB8AVhJbRx4l5kvOrPfWd4O8jQ2lXoamls=";
  versionLdflags = {
    "main.version" = "v${version}";
  };
  description = "Find deprecated Kubernetes apiVersions";
  homepage = "https://github.com/FairwindsOps/pluto";
}
