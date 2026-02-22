# Helmfile — Declarative spec for deploying Helm charts
{ mkGoTool, pkgs }:
let
  version = "1.1.9";
  src = pkgs.fetchFromGitHub {
    owner = "helmfile";
    repo = "helmfile";
    rev = "v${version}";
    hash = "sha256-WatJSiNi/rUaoBGgIdRjczpMiXAwRQ21ck/ATVKyZe0=";
  };
in mkGoTool pkgs {
  pname = "helmfile";
  inherit version src;
  vendorHash = "sha256-HTs176YgrQX8s+IrOqV4BQVZfhhFkNp+T3HbmmBFdTg=";
  proxyVendor = true;
  versionLdflags = {
    "github.com/helmfile/helmfile/pkg/app/version.Version" = "v${version}";
  };
  completions = { install = true; command = "helmfile"; };
  description = "Declarative spec for deploying Helm charts";
  homepage = "https://helmfile.readthedocs.io/";
}
