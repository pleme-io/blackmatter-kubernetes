# Tekton CLI — CLI for Tekton CI/CD pipelines
{ mkGoTool, pkgs }:
let
  version = "0.43.0";
  src = pkgs.fetchFromGitHub {
    owner = "tektoncd";
    repo = "cli";
    rev = "v${version}";
    hash = "sha256-75pyN+Sr5IttqrQYIveePabcuxnx8G48aiP5rw2v/Jo=";
  };
in mkGoTool pkgs {
  pname = "tektoncd-cli";
  inherit version src;
  vendorHash = null;
  subPackages = [ "cmd/tkn" ];
  versionLdflags = {
    "github.com/tektoncd/cli/pkg/cmd/version.clientVersion" = version;
  };
  completions = { install = true; command = "tkn"; };
  description = "CLI for Tekton CI/CD pipelines";
  homepage = "https://tekton.dev/";
}
