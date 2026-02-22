# Conftest — Policy testing for Kubernetes manifests
{ mkGoTool, pkgs }:
let
  version = "0.63.0";
  src = pkgs.fetchFromGitHub {
    owner = "open-policy-agent";
    repo = "conftest";
    rev = "v${version}";
    hash = "sha256-gmfzMup4fdsbdyUufxjcJRPF2faj3RUlvIn2ciyalaQ=";
  };
in mkGoTool pkgs {
  pname = "conftest";
  inherit version src;
  vendorHash = "sha256-pBUWM6st5FhhOki3n9NIN4/U8JB7Kq3Aph3AtQs+Ogg=";
  subPackages = [ "." ];
  versionLdflags = {
    "main.version" = version;
  };
  completions = { install = true; command = "conftest"; };
  description = "Policy testing for Kubernetes configuration files";
  homepage = "https://www.conftest.dev/";
}
