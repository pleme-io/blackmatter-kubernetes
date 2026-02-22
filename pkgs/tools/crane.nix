# Crane — Container registry CLI (go-containerregistry)
{ mkGoTool, pkgs }:
let
  version = "0.20.7";
  src = pkgs.fetchFromGitHub {
    owner = "google";
    repo = "go-containerregistry";
    rev = "v${version}";
    hash = "sha256-UDLKdeQ2Nxf5MCruN4IYNGL0xOp8Em2d+wmXX+R9ow4=";
  };
in mkGoTool pkgs {
  pname = "crane";
  inherit version src;
  vendorHash = null;
  subPackages = [ "cmd/crane" "cmd/gcrane" ];
  versionLdflags = {
    "github.com/google/go-containerregistry/cmd/crane/cmd.Version" = version;
  };
  completions = { install = true; command = "crane"; };
  description = "Container registry tool for interacting with remote images";
  homepage = "https://github.com/google/go-containerregistry";
}
