# Kubescape — Kubernetes security posture scanning
{ mkGoTool, pkgs }:
let
  version = "3.0.47";
  src = pkgs.fetchFromGitHub {
    owner = "kubescape";
    repo = "kubescape";
    rev = "v${version}";
    hash = "sha256-tXGFCKkuK8PGdgVGNXO5qVWB1+XPz092ovmLdVMY+yQ=";
    fetchSubmodules = true;
  };
in mkGoTool pkgs {
  pname = "kubescape";
  inherit version src;
  vendorHash = "sha256-1WmG+ffcwBCsAdBTXST0iZIcA8Mo0LRt317WDX2f/aM=";
  subPackages = [ "." ];
  proxyVendor = true;
  versionLdflags = {
    "github.com/kubescape/kubescape/v3/core/cautils.BuildNumber" = "v${version}";
  };
  completions = { install = true; command = "kubescape"; };
  description = "Kubernetes security posture management";
  homepage = "https://kubescape.io/";
}
