# Multus CNI — Multi-homed networking for Kubernetes pods
{ mkGoTool, pkgs }:

let
  version = "4.0.2";
  src = pkgs.fetchFromGitHub {
    owner = "k8snetworkplumbingwg";
    repo = "multus-cni";
    rev = "v${version}";
    sha256 = "sha256-Q6ACXOv1E3Ouki4ksdlUZFbWcDgo9xbCiTfEiVG5l18=";
  };
in mkGoTool pkgs {
  pname = "multus-cni";
  inherit version src;
  vendorHash = null; # vendored in-tree
  subPackages = [
    "cmd/multus-daemon"
    "cmd/multus-shim"
    "cmd/multus"
    "cmd/thin_entrypoint"
  ];
  ldflags = [
    "-s" "-w"
    "-X=gopkg.in/k8snetworkplumbingwg/multus-cni.v3/pkg/multus.version=${version}"
  ];
  platforms = pkgs.lib.platforms.linux;
  description = "Multi-homed networking for Kubernetes pods";
  homepage = "https://github.com/k8snetworkplumbingwg/multus-cni";
}
