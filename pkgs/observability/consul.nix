# Consul — Service mesh and discovery
{ mkGoTool, pkgs }:
let
  version = "1.22.1";
  src = pkgs.fetchFromGitHub {
    owner = "hashicorp";
    repo = "consul";
    rev = "v${version}";
    hash = "sha256-WlaJtiFlfLpdMATWHPbMneCqKzNcIRJrlf5TlbZgH8U=";
  };
in mkGoTool pkgs {
  pname = "consul";
  inherit version src;
  vendorHash = "sha256-QthyylbEkyfDPJIzIyL4u+d92MTZxIjZHBW39AZKmzo=";
  subPackages = [ "." ];
  versionLdflags = {
    "github.com/hashicorp/consul/version.GitDescribe" = "v${version}";
    "github.com/hashicorp/consul/version.Version" = version;
    "github.com/hashicorp/consul/version.VersionPrerelease" = "";
  };
  description = "Service mesh, discovery, and configuration for distributed systems";
  homepage = "https://www.consul.io/";
  license = pkgs.lib.licenses.bsl11;
}
