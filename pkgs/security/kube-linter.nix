# Kube-linter — Static analysis for Kubernetes
{ mkGoTool, pkgs }:
let
  version = "0.8.2";
  src = pkgs.fetchFromGitHub {
    owner = "stackrox";
    repo = "kube-linter";
    rev = "v${version}";
    hash = "sha256-nd8CLAp3MHuQs/firDPCZ4XlxVx73MMNGVNp5tsa1Rw=";
  };
in mkGoTool pkgs {
  pname = "kube-linter";
  inherit version src;
  vendorHash = "sha256-A8aNyMX9WtDDuqy6qOHTQkLnuckcsHEKZ3mfnC4Rx2s=";
  subPackages = [ "cmd/kube-linter" ];
  versionLdflags = {
    "golang.stackrox.io/kube-linter/internal/version.version" = version;
  };
  completions = { install = true; command = "kube-linter"; };
  description = "Static analysis tool for Kubernetes YAML and Helm charts";
  homepage = "https://docs.kubelinter.io/";
}
