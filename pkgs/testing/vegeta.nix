# Vegeta — HTTP load testing tool
{ mkGoTool, pkgs }:
let
  version = "12.13.0";
  src = pkgs.fetchFromGitHub {
    owner = "tsenart";
    repo = "vegeta";
    rev = "v${version}";
    hash = "sha256-Co+bGUSdiapDSJpcgOlCGMU3p0BfjtG1WjmErR8W/OM=";
  };
in mkGoTool pkgs {
  pname = "vegeta";
  inherit version src;
  vendorHash = "sha256-0Ho1HYckFHaWEE6Ti3fIL/t0hBj5MnKOd4fOZx+LYiE=";
  subPackages = [ "." ];
  ldflags = [
    "-s" "-w"
    "-X main.Version=${version}"
    "-X main.Commit=v${version}"
    "-X main.Date=1970-01-01T00:00:00Z"
  ];
  description = "Versatile HTTP load testing tool";
  homepage = "https://github.com/tsenart/vegeta";
  license = pkgs.lib.licenses.mit;
}
