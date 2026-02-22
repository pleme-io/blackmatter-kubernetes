# Fortio — Load testing for microservices
{ mkGoTool, pkgs }:
let
  version = "1.74.0";
  src = pkgs.fetchFromGitHub {
    owner = "fortio";
    repo = "fortio";
    rev = "v${version}";
    hash = "sha256-5JWSX9w1GlxE3iZlGzRuc1Udl3PNV+rfhbtWS8dzyIg=";
  };
in mkGoTool pkgs {
  pname = "fortio";
  inherit version src;
  vendorHash = "sha256-Em/mYas8uZHra7cWXXslHfjVuU2LakG1iS49EYch8Lc=";
  subPackages = [ "." ];
  extraAttrs = { env.CGO_ENABLED = "0"; };
  description = "Load testing library, command line tool, and web UI for microservices";
  homepage = "https://fortio.org/";
}
