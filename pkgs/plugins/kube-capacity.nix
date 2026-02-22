# kube-capacity — Resource usage viewer for Kubernetes
{ mkGoTool, pkgs }:
let
  version = "0.8.0";
  src = pkgs.fetchFromGitHub {
    owner = "robscott";
    repo = "kube-capacity";
    rev = "v${version}";
    hash = "sha256-zAwCz4Qs1OF/CdSmy9p4X9hL9iNkAH/EeSU2GgekzV8=";
  };
in mkGoTool pkgs {
  pname = "kube-capacity";
  inherit version src;
  vendorHash = "sha256-YME4AXpHvr1bNuc/HoHxam+7ZkwLzjhIvFSfD4hga1A=";
  description = "Overview of resource requests, limits, and utilization in a Kubernetes cluster";
  homepage = "https://github.com/robscott/kube-capacity";
}
