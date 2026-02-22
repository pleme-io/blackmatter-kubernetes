# Cosign — Container image signing and verification
{ mkGoTool, pkgs }:
let
  version = "3.0.4";
  src = pkgs.fetchFromGitHub {
    owner = "sigstore";
    repo = "cosign";
    rev = "v${version}";
    hash = "sha256-Ddq9MJNRZ+ywJwxIUP4nhag8UZIH/hOYnF71P3+gI/0=";
  };
in mkGoTool pkgs {
  pname = "cosign";
  inherit version src;
  vendorHash = "sha256-TuA3LwZFAKjZ4aoX92tYd7eziG5N1vDOTsEgwhg5n6w=";
  subPackages = [ "cmd/cosign" ];
  tags = [ "pivkey" "pkcs11key" ];
  versionLdflags = {
    "sigs.k8s.io/release-utils/version.gitVersion" = "v${version}";
    "sigs.k8s.io/release-utils/version.gitTreeState" = "clean";
  };
  completions = { install = true; command = "cosign"; };
  description = "Container signing, verification, and storage in OCI registries";
  homepage = "https://sigstore.dev/";
}
