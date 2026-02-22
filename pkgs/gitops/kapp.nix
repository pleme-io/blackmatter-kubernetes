# kapp — Carvel application deployment tool
{ mkGoTool, pkgs }:
let
  version = "0.65.0";
  src = pkgs.fetchFromGitHub {
    owner = "carvel-dev";
    repo = "kapp";
    rev = "v${version}";
    hash = "sha256-D46QgNzkCNg0GDsaN1GG0yuWbNeioIErYhbgjwMsTWA=";
  };
in mkGoTool pkgs {
  pname = "kapp";
  inherit version src;
  vendorHash = null;
  extraAttrs = { env.CGO_ENABLED = "0"; };
  versionLdflags = {
    "carvel.dev/kapp/pkg/kapp/version.Version" = version;
  };
  completions = { install = true; command = "kapp"; };
  description = "Carvel application deployment tool for Kubernetes";
  homepage = "https://carvel.dev/kapp/";
}
