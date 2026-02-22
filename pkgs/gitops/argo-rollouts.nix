# Argo Rollouts — Progressive delivery for Kubernetes
{ mkGoTool, pkgs }:
let
  version = "1.8.3";
  src = pkgs.fetchFromGitHub {
    owner = "argoproj";
    repo = "argo-rollouts";
    rev = "v${version}";
    hash = "sha256-OCFbnBSFSXcbXHT48sS8REAt6CtNFPCNTIfKRBj19DM=";
  };
in mkGoTool pkgs {
  pname = "argo-rollouts";
  inherit version src;
  vendorHash = "sha256-2zarm9ZvPJ5uwEYvYI60uaN5MONKE8gd+i6TPHdD3PU=";
  subPackages = [ "cmd/kubectl-argo-rollouts" ];
  versionLdflags = {
    "github.com/argoproj/argo-rollouts/utils/version.version" = version;
    "github.com/argoproj/argo-rollouts/utils/version.buildDate" = "1970-01-01T00:00:00Z";
  };
  extraPostInstall = ''
    ln -s $out/bin/kubectl-argo-rollouts $out/bin/argo-rollouts
  '';
  description = "Progressive delivery controller and kubectl plugin";
  homepage = "https://argoproj.github.io/rollouts/";
}
