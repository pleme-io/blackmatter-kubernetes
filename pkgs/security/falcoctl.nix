# Falcoctl — Falco administrative CLI
{ mkGoTool, pkgs }:
let
  version = "0.11.4";
  src = pkgs.fetchFromGitHub {
    owner = "falcosecurity";
    repo = "falcoctl";
    rev = "v${version}";
    hash = "sha256-BEnThboYmcZKL1o6Js8zHWvbU1OSH7BRcohBzlqNZKI=";
  };
in mkGoTool pkgs {
  pname = "falcoctl";
  inherit version src;
  vendorHash = "sha256-SIEd/YVwEF4FleudzvYoOW2GnIflKMYRDEiWSv77H7o=";
  versionLdflags = {
    "github.com/falcosecurity/falcoctl/cmd/version.semVersion" = version;
  };
  completions = { install = true; command = "falcoctl"; };
  description = "Administrative tooling for Falco";
  homepage = "https://falco.org/";
}
