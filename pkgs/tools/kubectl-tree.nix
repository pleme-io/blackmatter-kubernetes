# Kubectl-tree — kubectl plugin to explore ownership relationships
{ mkGoTool, pkgs }:

let
  version = "0.4.6";
  src = pkgs.fetchFromGitHub {
    owner = "ahmetb";
    repo = "kubectl-tree";
    rev = "v${version}";
    sha256 = "sha256-o5LfWVirp6ENYxqiUSvBDenAzeIIeio2WDD9Ll7Khgk=";
  };
in mkGoTool pkgs {
  pname = "kubectl-tree";
  inherit version src;
  vendorHash = "sha256-8vfZDegdPUh7U1ApOYl3PgTPba5cIk4lwRo+5jTZU0s=";
  description = "kubectl plugin to explore ownership relationships between Kubernetes objects";
  homepage = "https://github.com/ahmetb/kubectl-tree";
}
