# k6 — Modern load testing tool
{ mkGoTool, pkgs }:
let
  version = "1.6.0";
  src = pkgs.fetchFromGitHub {
    owner = "grafana";
    repo = "k6";
    rev = "v${version}";
    hash = "sha256-rfurCWplI21vEYEArxp4wrAn6oOWenMkGetFDy5WCAY=";
  };
in mkGoTool pkgs {
  pname = "k6";
  inherit version src;
  vendorHash = null;
  subPackages = [ "./" ];
  completions = { install = true; command = "k6"; };
  description = "Modern load testing tool using Go and JavaScript";
  homepage = "https://k6.io/";
  license = pkgs.lib.licenses.agpl3Plus;
}
