# Kube-score — Kubernetes object analysis with recommendations
{ mkGoTool, pkgs }:

let
  version = "1.20.0";
  src = pkgs.fetchFromGitHub {
    owner = "zegl";
    repo = "kube-score";
    rev = "v${version}";
    hash = "sha256-ZqhuqPWCfJKi38Jdazr5t5Wulsqzl1D4/81ZTvW10Co=";
  };
in mkGoTool pkgs {
  pname = "kube-score";
  inherit version src;
  vendorHash = "sha256-uv+82x94fEa/3tjcofLGIPhJpwUzSkEbarGVq8wVEUc=";
  ldflags = [
    "-s" "-w"
    "-X=main.version=${version}"
    "-X=main.commit=v${version}"
  ];
  description = "Kubernetes object analysis with recommendations for improved reliability and security";
  homepage = "https://kube-score.com/";
}
