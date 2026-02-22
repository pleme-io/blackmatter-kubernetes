# Kyverno — Kubernetes policy engine CLI
{ mkGoTool, pkgs }:
let
  version = "1.16.2";
  src = pkgs.fetchFromGitHub {
    owner = "kyverno";
    repo = "kyverno";
    rev = "v${version}";
    hash = "sha256-wXoqE3AZ5PQ8nxkJhfGrNdyJBKW8BF0loqqCs6A2Etg=";
  };
in mkGoTool pkgs {
  pname = "kyverno";
  inherit version src;
  vendorHash = "sha256-7zonEXXrd5+QaQQcgHwGwj665YB9gBxtE8Yi09SGsPU=";
  subPackages = [ "cmd/cli/kubectl-kyverno" ];
  versionLdflags = {
    "github.com/kyverno/kyverno/pkg/version.BuildVersion" = version;
    "github.com/kyverno/kyverno/pkg/version.BuildTime" = "1970-01-01T00:00:00Z";
  };
  extraPostInstall = ''
    mv $out/bin/kubectl-kyverno $out/bin/kyverno
  '';
  description = "Kubernetes native policy management CLI";
  homepage = "https://kyverno.io/";
}
