# Helm — Kubernetes package manager
{ mkGoTool, pkgs }:

let
  version = "3.19.1";
  src = pkgs.fetchFromGitHub {
    owner = "helm";
    repo = "helm";
    rev = "v${version}";
    sha256 = "sha256-1Cc7W6qyawcg5ZfjsGWH7gScdRhcYpqppjzD83QWV60=";
  };
in mkGoTool pkgs {
  pname = "helm";
  inherit version src;
  vendorHash = "sha256-81qCRwp57PpzK/eavycOLFYsuD8uVq46h12YVlJRK7Y=";
  subPackages = [ "cmd/helm" ];
  ldflags = [
    "-w" "-s"
    "-X helm.sh/helm/v3/internal/version.version=v${version}"
    "-X helm.sh/helm/v3/internal/version.gitCommit=v${version}"
  ];
  completions = { install = true; command = "helm"; };
  description = "Kubernetes package manager";
  homepage = "https://helm.sh/";
}
