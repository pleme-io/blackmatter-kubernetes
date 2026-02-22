# Thanos — Highly available Prometheus setup with long term storage
{ mkGoTool, pkgs }:
let
  version = "0.40.1";
  src = pkgs.fetchFromGitHub {
    owner = "thanos-io";
    repo = "thanos";
    rev = "v${version}";
    hash = "sha256-g0xvtBwPoX906xHdyOEUfudio/9MZhkzdBp5FcATRsM=";
  };
  t = "github.com/prometheus/common/version";
in mkGoTool pkgs {
  pname = "thanos";
  inherit version src;
  vendorHash = "sha256-ukKoiA7UhqDdMvAWYL5BGf6+FSPSkcRR/Scj5o/MMKc=";
  subPackages = [ "cmd/thanos" ];
  tags = [ "netgo" "slicelabels" ];
  ldflags = [
    "-s" "-w"
    "-X ${t}.Version=${version}"
    "-X ${t}.Revision=unknown"
    "-X ${t}.Branch=unknown"
    "-X ${t}.BuildUser=nix"
    "-X ${t}.BuildDate=1970-01-01T00:00:00Z"
  ];
  description = "Highly available Prometheus setup with long term storage capabilities";
  homepage = "https://thanos.io/";
}
