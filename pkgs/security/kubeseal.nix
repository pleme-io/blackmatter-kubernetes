# Kubeseal — Sealed Secrets CLI
{ mkGoTool, pkgs }:
let
  version = "0.34.0";
  src = pkgs.fetchFromGitHub {
    owner = "bitnami-labs";
    repo = "sealed-secrets";
    rev = "v${version}";
    hash = "sha256-Yu0fjVgYiZ+MTF8aJXjoQ8VZuD0tr6znFgYkTqIaZDU=";
  };
in mkGoTool pkgs {
  pname = "kubeseal";
  inherit version src;
  vendorHash = "sha256-gvMExOJQHBid1GAroYufuYGzoZm2yVEKO3Wafvp7Ad0=";
  subPackages = [ "cmd/kubeseal" ];
  description = "Sealed Secrets CLI for Kubernetes";
  homepage = "https://sealed-secrets.netlify.app/";
}
