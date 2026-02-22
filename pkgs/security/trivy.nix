# Trivy — Container and Kubernetes vulnerability scanner
{ mkGoTool, pkgs }:
let
  version = "0.69.0";
  src = pkgs.fetchFromGitHub {
    owner = "aquasecurity";
    repo = "trivy";
    rev = "v${version}";
    hash = "sha256-auCbZmVr7LzYrw+IOpXBZPUs2YmcPAzr5fo12vSyHeM=";
  };
in mkGoTool pkgs {
  pname = "trivy";
  inherit version src;
  vendorHash = "sha256-GLHr2bLAt3jIOz+E38fryca3r9QqC31sjSOXXk3UP0w=";
  proxyVendor = true;
  subPackages = [ "cmd/trivy" ];
  versionLdflags = {
    "main.version" = version;
  };
  completions = { install = true; command = "trivy"; };
  extraAttrs = {
    env.GOEXPERIMENT = "jsonv2";
  };
  description = "Container and Kubernetes vulnerability scanner";
  homepage = "https://trivy.dev/";
}
