# mimirtool — CLI for Grafana Mimir metrics storage
{ mkGoTool, pkgs }:
let
  version = "3.0.2";
  src = pkgs.fetchFromGitHub {
    owner = "grafana";
    repo = "mimir";
    # Mimir uses non-standard tag naming
    rev = "mimir-${version}";
    hash = "sha256-8dym3E6VinpExE4A+ekbhiQ+Zhwvue6/s1mAhBkwPMU=";
  };
  t = "github.com/grafana/mimir/pkg/util/version";
in mkGoTool pkgs {
  pname = "mimirtool";
  inherit version src;
  vendorHash = null;
  subPackages = [ "cmd/mimirtool" ];
  ldflags = [
    "-s" "-w"
    "-X ${t}.Version=${version}"
    "-X ${t}.Revision=unknown"
    "-X ${t}.Branch=unknown"
  ];
  description = "CLI for Grafana Mimir horizontally scalable metrics storage";
  homepage = "https://grafana.com/oss/mimir/";
}
