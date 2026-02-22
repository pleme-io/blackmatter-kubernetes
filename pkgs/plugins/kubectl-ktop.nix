# kubectl-ktop — Top-like tool for Kubernetes clusters
{ mkGoTool, pkgs }:
let
  version = "0.5.3";
  src = pkgs.fetchFromGitHub {
    owner = "vladimirvivien";
    repo = "ktop";
    rev = "v${version}";
    hash = "sha256-CUMQsgXhypSSR1MC7hJtkZgRcM2/x6jsPVudIvRy9qM=";
  };
in mkGoTool pkgs {
  pname = "kubectl-ktop";
  inherit version src;
  vendorHash = "sha256-kSDbQFiZ8XMKyW7aYKe1s0pq038YC+RORCtMXFI+knA=";
  subPackages = [ "." ];
  versionLdflags = {
    "github.com/vladimirvivien/ktop/buildinfo.Version" = "v${version}";
    "github.com/vladimirvivien/ktop/buildinfo.GitSHA" = "v${version}";
  };
  extraPostInstall = ''
    ln -s $out/bin/ktop $out/bin/kubectl-ktop
  '';
  description = "Top-like tool for your Kubernetes clusters";
  homepage = "https://github.com/vladimirvivien/ktop";
}
