# logcli — CLI for querying Grafana Loki
{ mkGoTool, pkgs }:
let
  version = "3.6.6";
  src = pkgs.fetchFromGitHub {
    owner = "grafana";
    repo = "loki";
    rev = "v${version}";
    hash = "sha256-Mdopa7Nhdcwn4VBz/R5zI3Zccuht2hIdnAeCsAS6B+0=";
  };
  t = "github.com/grafana/loki/v3/pkg/util/build";
in mkGoTool pkgs {
  pname = "logcli";
  inherit version src;
  vendorHash = null;
  subPackages = [ "cmd/logcli" ];
  ldflags = [
    "-s" "-w"
    "-X ${t}.Version=${version}"
    "-X ${t}.BuildUser=nix"
    "-X ${t}.BuildDate=1970-01-01T00:00:00Z"
    "-X ${t}.Branch=unknown"
    "-X ${t}.Revision=unknown"
  ];
  description = "CLI for querying Grafana Loki log aggregation system";
  homepage = "https://grafana.com/oss/loki/";
}
