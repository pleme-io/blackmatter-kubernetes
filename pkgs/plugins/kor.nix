# kor — Discover unused Kubernetes resources
{ mkGoTool, pkgs }:
let
  version = "0.6.7";
  src = pkgs.fetchFromGitHub {
    owner = "yonahd";
    repo = "kor";
    rev = "v${version}";
    hash = "sha256-d8/b1O/dEeJzf9xaTHvAUbx2tFk7LjuOnACXYEIFsME=";
  };
in mkGoTool pkgs {
  pname = "kor";
  inherit version src;
  vendorHash = "sha256-nFgf1eGbIQ1R/cj+ikYIaw2dqOSoEAG4sFPAqF1CFAQ=";
  versionLdflags = {
    "github.com/yonahd/kor/pkg/utils.Version" = version;
  };
  description = "Discover unused Kubernetes resources";
  homepage = "https://github.com/yonahd/kor";
  license = pkgs.lib.licenses.mit;
}
