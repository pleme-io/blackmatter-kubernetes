# kubectl-images — Show container images used in the cluster
{ mkGoTool, pkgs }:
let
  version = "0.6.3";
  src = pkgs.fetchFromGitHub {
    owner = "chenjiandongx";
    repo = "kubectl-images";
    rev = "v${version}";
    hash = "sha256-FHfj2qRypqQA0Vj9Hq7wuYd0xmpD+IZj3MkwKljQio0=";
  };
in mkGoTool pkgs {
  pname = "kubectl-images";
  inherit version src;
  vendorHash = "sha256-8zV2iZ10H5X6fkRqElfc7lOf3FhmDzR2lb3Jgyhjyio=";
  extraPostInstall = ''
    mv $out/bin/cmd $out/bin/kubectl-images
  '';
  description = "Show container images used in the cluster";
  homepage = "https://github.com/chenjiandongx/kubectl-images";
  license = pkgs.lib.licenses.mit;
}
