# KWOK — Kubernetes WithOut Kubelet (cluster simulation)
{ mkGoTool, pkgs }:
let
  version = "0.7.0";
  src = pkgs.fetchFromGitHub {
    owner = "kubernetes-sigs";
    repo = "kwok";
    rev = "v${version}";
    hash = "sha256-gtDGkAXbNCWUVGL4+C6mOkWwrPcik6+nGEQNrjLb57U=";
  };
in mkGoTool pkgs {
  pname = "kwok";
  inherit version src;
  vendorHash = "sha256-UNso+e/zYah0jApHZgWnQ3cUSV44HsMqPy4q4JMCyiA=";
  subPackages = [ "cmd/kwok" "cmd/kwokctl" ];
  versionLdflags = {
    "sigs.k8s.io/kwok/pkg/consts.Version" = "v${version}";
  };
  description = "Simulate massive Kubernetes clusters with low resource usage";
  homepage = "https://kwok.sigs.k8s.io/";
}
