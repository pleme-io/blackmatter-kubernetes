# cmctl — cert-manager CLI
{ mkGoTool, pkgs }:
let
  version = "2.4.0";
  src = pkgs.fetchFromGitHub {
    owner = "cert-manager";
    repo = "cmctl";
    rev = "v${version}";
    hash = "sha256-wOtpaohPjBWQkaZbA1Fbh97kVxMTEGuqCtIhviJGOrU=";
  };
in mkGoTool pkgs {
  pname = "cmctl";
  inherit version src;
  vendorHash = "sha256-ocQDysrJUbCDnWZ2Ul3kDqPTpvmpgA3Wz+L5/fIkrh4=";
  subPackages = [ "." ];
  ldflags = [
    "-s" "-w"
    "-X github.com/cert-manager/cert-manager/pkg/util.AppVersion=v${version}"
    "-X github.com/cert-manager/cert-manager/pkg/util.AppGitCommit=v${version}"
  ];
  completions = { install = true; command = "cmctl"; };
  description = "CLI for cert-manager certificate management on Kubernetes";
  homepage = "https://cert-manager.io/";
}
