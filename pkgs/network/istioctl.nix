# Istioctl — CLI for Istio service mesh
{ mkGoTool, pkgs }:

let
  version = "1.28.3";
  src = pkgs.fetchFromGitHub {
    owner = "istio";
    repo = "istio";
    rev = version; # no "v" prefix
    hash = "sha256-V8yG0Dj2/KevTiG9C68SlkLzo5xkblxMYhsZOq1ucgc=";
  };
in mkGoTool pkgs {
  pname = "istioctl";
  inherit version src;
  vendorHash = "sha256-QcPtQV3sO+B2NtxJvOi5x5hlAI1ace4LqWO84fAovGw=";
  subPackages = [ "istioctl/cmd/istioctl" ];
  ldflags = [
    "-s" "-w"
    "-X istio.io/istio/pkg/version.buildVersion=${version}"
    "-X istio.io/istio/pkg/version.buildStatus=Nix"
    "-X istio.io/istio/pkg/version.buildTag=${version}"
    "-X istio.io/istio/pkg/version.buildHub=docker.io/istio"
  ];
  completions = { install = true; command = "istioctl"; };
  description = "CLI for Istio service mesh";
  homepage = "https://istio.io/";
}
