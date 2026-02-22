# Helm-docs — Auto-generate documentation from Helm charts
{ mkGoTool, pkgs }:
let
  version = "1.14.2";
  src = pkgs.fetchFromGitHub {
    owner = "norwoodj";
    repo = "helm-docs";
    rev = "v${version}";
    hash = "sha256-a7alzjh+vjJPw/g9yaYkOUvwpgiqCrtKTBkV1EuGYtk=";
  };
in mkGoTool pkgs {
  pname = "helm-docs";
  inherit version src;
  vendorHash = "sha256-9VSjxnc804A+PTMy0ZoNWNkHAjh3/kMK0XoEfI/LgEY=";
  subPackages = [ "cmd/helm-docs" ];
  versionLdflags = {
    "main.version" = "v${version}";
  };
  description = "Auto-generate documentation from Helm charts";
  homepage = "https://github.com/norwoodj/helm-docs";
}
