# CoreDNS — DNS and service discovery for Kubernetes
{ mkGoTool, pkgs }:
let
  version = "1.14.1";
  src = pkgs.fetchFromGitHub {
    owner = "coredns";
    repo = "coredns";
    rev = "v${version}";
    hash = "sha256-WcRX2BCWIQ8e0FYCIAzCdexz+Nl+/kKicQkhEw2AVMs=";
  };
in mkGoTool pkgs {
  pname = "coredns";
  inherit version src;
  vendorHash = "sha256-MbuG9gb4P3yTtBT+utTC/sFsETEvPHbv8Rf5Vgjx9w8=";
  description = "DNS and service discovery for Kubernetes";
  homepage = "https://coredns.io/";
}
