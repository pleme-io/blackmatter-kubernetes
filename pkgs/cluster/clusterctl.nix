# Clusterctl — Cluster API management tool
{ mkGoTool, pkgs }:
let
  version = "1.12.2";
  src = pkgs.fetchFromGitHub {
    owner = "kubernetes-sigs";
    repo = "cluster-api";
    rev = "v${version}";
    hash = "sha256-AaGJhdBTyCxUK+qm++McS6rFlgAdv/7SjQHvaNRn6YU=";
  };
in mkGoTool pkgs {
  pname = "clusterctl";
  inherit version src;
  vendorHash = "sha256-3dh9Y8R4OeUayyqNyrvUcrnSi/4s9x6oMrAADXR5rnw=";
  subPackages = [ "cmd/clusterctl" ];
  versionLdflags = {
    "sigs.k8s.io/cluster-api/version.gitVersion" = "v${version}";
  };
  completions = { install = true; command = "clusterctl"; };
  description = "Cluster API management CLI";
  homepage = "https://cluster-api.sigs.k8s.io/";
}
