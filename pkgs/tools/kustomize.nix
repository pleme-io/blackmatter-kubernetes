# Kustomize — Kubernetes manifest customization tool
{ mkGoTool, pkgs }:

let
  version = "5.8.0";
  src = pkgs.fetchFromGitHub {
    owner = "kubernetes-sigs";
    repo = "kustomize";
    rev = "kustomize/v${version}";
    hash = "sha256-BOM0m/bigELUf6xHjLbI8wzSscF0lhwCjIxa87xBbWM=";
  };
in mkGoTool pkgs {
  pname = "kustomize";
  inherit version src;
  vendorHash = "sha256-kwvfxHXL189PSK7+PnOr+1TSjuX3uHkV4VnG3gSW5v0=";
  proxyVendor = true;
  modRoot = "kustomize";
  versionLdflags = {
    "sigs.k8s.io/kustomize/api/provenance.version" = "v${version}";
    "sigs.k8s.io/kustomize/api/provenance.gitCommit" = "kustomize/v${version}";
  };
  completions = { install = true; command = "kustomize"; };
  description = "Kubernetes manifest customization tool";
  homepage = "https://kustomize.io/";
}
