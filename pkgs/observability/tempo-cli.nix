# tempo-cli — CLI for Grafana Tempo distributed tracing
{ mkGoTool, pkgs }:
let
  version = "2.10.0";
  src = pkgs.fetchFromGitHub {
    owner = "grafana";
    repo = "tempo";
    rev = "v${version}";
    hash = "sha256-ciiJg8PdvifYGalfo/V8RFTKkZ8pHM9RlwfGRKeRAhU=";
    fetchSubmodules = true;
  };
in mkGoTool pkgs {
  pname = "tempo-cli";
  inherit version src;
  vendorHash = null;
  subPackages = [ "cmd/tempo-cli" ];
  ldflags = [
    "-s" "-w"
    "-X=main.Version=${version}"
    "-X=main.Branch=release"
    "-X=main.Revision=${version}"
  ];
  description = "CLI for Grafana Tempo distributed tracing backend";
  homepage = "https://grafana.com/oss/tempo/";
}
