# Grype — Container vulnerability scanner
{ mkGoTool, pkgs }:
let
  version = "0.105.0";
  src = pkgs.fetchFromGitHub {
    owner = "anchore";
    repo = "grype";
    rev = "v${version}";
    hash = "sha256-+8fCQ/9S4qwPfq/XM5G7LdNl8VQvBxIl67RMqlB6rUI=";
  };
in mkGoTool pkgs {
  pname = "grype";
  inherit version src;
  vendorHash = "sha256-dYtTYkSVIO5k9kkodhIUWrlNXfQNCUjTUwz4+n6IMtY=";
  proxyVendor = true;
  subPackages = [ "cmd/grype" ];
  versionLdflags = {
    "main.version" = version;
    "main.buildDate" = "1970-01-01T00:00:00Z";
  };
  completions = { install = true; command = "grype"; };
  description = "Container image vulnerability scanner";
  homepage = "https://github.com/anchore/grype";
}
