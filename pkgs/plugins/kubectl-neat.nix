# kubectl-neat — Clean up Kubernetes YAML output
{ mkGoTool, pkgs }:
let
  version = "2.0.3";
  src = pkgs.fetchFromGitHub {
    owner = "itaysk";
    repo = "kubectl-neat";
    rev = "v${version}";
    hash = "sha256-j8v0zJDBqHzmLamIZPW9UvMe9bv/m3JUQKY+wsgMTFk=";
  };
in mkGoTool pkgs {
  pname = "kubectl-neat";
  inherit version src;
  vendorHash = "sha256-vGXoYR0DT9V1BD/FN/4szOal0clsLlqReTFkAd2beMw=";
  description = "Clean up Kubernetes YAML and JSON output to make it readable";
  homepage = "https://github.com/itaysk/kubectl-neat";
}
