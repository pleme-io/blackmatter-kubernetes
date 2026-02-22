# vcluster — Virtual Kubernetes clusters
{ mkGoTool, pkgs }:
let
  version = "0.31.0";
  src = pkgs.fetchFromGitHub {
    owner = "loft-sh";
    repo = "vcluster";
    rev = "v${version}";
    hash = "sha256-yGvKZ70+x+PQiTCB8MxUplymlQLm9iT+ryBHFF1a/Os=";
  };
in mkGoTool pkgs {
  pname = "vcluster";
  inherit version src;
  vendorHash = null;
  subPackages = [ "cmd/vclusterctl" ];
  versionLdflags = {
    "main.version" = "v${version}";
  };
  extraPostInstall = ''
    mv $out/bin/vclusterctl $out/bin/vcluster
  '';
  description = "Create fully functional virtual Kubernetes clusters";
  homepage = "https://www.vcluster.com/";
}
