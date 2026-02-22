# Talosctl — Talos Linux management CLI
{ mkGoTool, pkgs }:
let
  version = "1.12.2";
  src = pkgs.fetchFromGitHub {
    owner = "siderolabs";
    repo = "talos";
    rev = "v${version}";
    hash = "sha256-E3WeFu4PpgJN+ZLeTfAqqkTgInu/imytpdCixM33wiw=";
  };
in mkGoTool pkgs {
  pname = "talosctl";
  inherit version src;
  vendorHash = "sha256-1RNNAGCvmtau7oI4gSUpz+savxSugp2yh2THwt/mNG4=";
  subPackages = [ "cmd/talosctl" ];
  versionLdflags = {
    "github.com/siderolabs/talos/pkg/machinery/version.Tag" = "v${version}";
  };
  completions = { install = true; command = "talosctl"; };
  extraAttrs = { env.GOWORK = "off"; };
  description = "Talos Linux management CLI";
  homepage = "https://www.talos.dev/";
}
