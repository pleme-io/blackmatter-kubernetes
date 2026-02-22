# Cilium CLI — CLI for Cilium CNI management
{ mkGoTool, pkgs }:

let
  version = "0.19.0";
  src = pkgs.fetchFromGitHub {
    owner = "cilium";
    repo = "cilium-cli";
    tag = "v${version}";
    hash = "sha256-pW+9UN+pWkKCYRTvZxslrPgczOezVnPpDF5XdRHCh+g=";
  };
in mkGoTool pkgs {
  pname = "cilium-cli";
  inherit version src;
  vendorHash = null; # vendored in-tree
  subPackages = [ "cmd/cilium" ];
  ldflags = [
    "-s" "-w"
    "-X=github.com/cilium/cilium/cilium-cli/defaults.CLIVersion=${version}"
  ];
  completions = { install = true; command = "cilium"; };
  extraAttrs = {
    env.HOME = "$TMPDIR";
  };
  description = "CLI for installing, managing, and troubleshooting Cilium";
  homepage = "https://cilium.io/";
}
