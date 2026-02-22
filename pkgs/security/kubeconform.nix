# Kubeconform — Fast Kubernetes manifest validator
{ mkGoTool, pkgs }:
let
  version = "0.7.0";
  src = pkgs.fetchFromGitHub {
    owner = "yannh";
    repo = "kubeconform";
    rev = "v${version}";
    hash = "sha256-FTUPARckpecz1V/Io4rY6SXhlih3VJr/rTGAiik4ALA=";
  };
in mkGoTool pkgs {
  pname = "kubeconform";
  inherit version src;
  vendorHash = null;
  versionLdflags = {
    "main.version" = "v${version}";
  };
  description = "Fast Kubernetes manifest validation tool";
  homepage = "https://github.com/yannh/kubeconform";
}
