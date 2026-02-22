# Hubble — Cilium network observability CLI
{ mkGoTool, pkgs }:
let
  version = "1.18.5";
  src = pkgs.fetchFromGitHub {
    owner = "cilium";
    repo = "hubble";
    rev = "v${version}";
    hash = "sha256-0R9Bm+8eiCOfsCs2oCBjZQR/N8z0DmkGBC/6Fy4JNyM=";
  };
in mkGoTool pkgs {
  pname = "hubble";
  inherit version src;
  vendorHash = null;
  versionLdflags = {
    "github.com/cilium/cilium/hubble/pkg.GitBranch" = "none";
    "github.com/cilium/cilium/hubble/pkg.GitHash" = "none";
    "github.com/cilium/cilium/hubble/pkg.Version" = version;
  };
  completions = { install = true; command = "hubble"; };
  description = "Network, service and security observability for Kubernetes using eBPF";
  homepage = "https://github.com/cilium/hubble/";
}
