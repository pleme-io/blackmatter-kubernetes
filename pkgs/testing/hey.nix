# hey — HTTP load generator
{ mkGoTool, pkgs }:
let
  version = "0.1.4";
  src = pkgs.fetchFromGitHub {
    owner = "rakyll";
    repo = "hey";
    rev = "v${version}";
    hash = "sha256-6789aWtTMU+ax/tKrwi/HQYaiPdeDaJIUOty+rOeTT8=";
  };
in mkGoTool pkgs {
  pname = "hey";
  inherit version src;
  vendorHash = null;
  description = "HTTP load generator, ApacheBench (ab) replacement";
  homepage = "https://github.com/rakyll/hey";
}
