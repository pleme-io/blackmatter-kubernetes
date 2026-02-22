# Kubecolor — Colorized kubectl output
{ mkGoTool, pkgs }:

let
  version = "0.5.3";
  src = pkgs.fetchFromGitHub {
    owner = "kubecolor";
    repo = "kubecolor";
    rev = "v${version}";
    sha256 = "sha256-F/ws7KevH0mGtSqp+iHyWpNccIBdF5gIoZfmLJ5H4YM=";
  };
in mkGoTool pkgs {
  pname = "kubecolor";
  inherit version src;
  vendorHash = "sha256-QenYTQTNXaBvzpyVHOCx3lEheiWZMfulEfzB+ll+q+4=";
  subPackages = [ "." ];
  versionLdflags = {
    "main.Version" = version;
  };
  description = "Colorized kubectl output";
  homepage = "https://github.com/kubecolor/kubecolor";
}
