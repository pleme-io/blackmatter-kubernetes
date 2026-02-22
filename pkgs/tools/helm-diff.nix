# Helm-diff — Helm plugin showing chart upgrade diff
{ mkGoTool, pkgs }:
let
  version = "3.13.1";
  src = pkgs.fetchFromGitHub {
    owner = "databus23";
    repo = "helm-diff";
    rev = "v${version}";
    hash = "sha256-7LkXoPhLqZtc1jy8JOkZrHWSIqB2oZLHsEyeNk3vl60=";
  };
in mkGoTool pkgs {
  pname = "helm-diff";
  inherit version src;
  vendorHash = "sha256-QSbml6M+ftQy4n+ybYWf2gCsbVmrnhX09w3ffW/JgUM=";
  versionLdflags = {
    "github.com/databus23/helm-diff/v3/cmd.Version" = version;
  };
  description = "Helm plugin showing a diff of what a helm upgrade would change";
  homepage = "https://github.com/databus23/helm-diff";
}
