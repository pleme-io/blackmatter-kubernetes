# kubent — Kubernetes deprecation checker
{ mkGoTool, pkgs }:
let
  version = "0.7.3";
  src = pkgs.fetchFromGitHub {
    owner = "doitintl";
    repo = "kube-no-trouble";
    # kubent uses version without v prefix for tags
    rev = version;
    hash = "sha256-7bn7DxbZ/Nqob7ZEWRy1UVg97FiJN5JWEgpH1CDz6jQ=";
  };
in mkGoTool pkgs {
  pname = "kubent";
  inherit version src;
  vendorHash = "sha256-+V+/TK60V8NYUDfF5/EgSZg4CLBn6Mt57diiyXm179k=";
  subPackages = [ "cmd/kubent" ];
  versionLdflags = {
    "main.version" = "v${version}";
  };
  description = "Easily check your cluster for use of deprecated APIs";
  homepage = "https://github.com/doitintl/kube-no-trouble";
  license = pkgs.lib.licenses.mit;
}
