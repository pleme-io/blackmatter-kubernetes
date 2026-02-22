# kube-state-metrics — Kubernetes cluster-level metrics exporter
# NOTE: Uses buildGoModule directly because it needs excludedPackages
{ pkgs }:
let
  version = "2.17.0";
  src = pkgs.fetchFromGitHub {
    owner = "kubernetes";
    repo = "kube-state-metrics";
    rev = "v${version}";
    hash = "sha256-w55FOWw9p7yV/bt4leZucOLqjVyHYFF+gVLWLGQKF9M=";
  };
in pkgs.buildGoModule {
  pname = "kube-state-metrics";
  inherit version src;
  vendorHash = "sha256-pcoqeYyOehFNkwD4fWqrk9725BJkv+8sKy1NLv+HJPE=";

  excludedPackages = [
    "./tests/e2e"
    "./tools"
  ];

  doCheck = false;

  meta = {
    description = "Kubernetes cluster-level metrics exporter";
    homepage = "https://github.com/kubernetes/kube-state-metrics";
    license = pkgs.lib.licenses.asl20;
    mainProgram = "kube-state-metrics";
    platforms = pkgs.lib.platforms.unix;
  };
}
