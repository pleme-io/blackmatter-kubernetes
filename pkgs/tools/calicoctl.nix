# Calicoctl — CLI for Calico network policy management
{ mkGoTool, pkgs }:

let
  version = "3.31.3";
  src = pkgs.fetchFromGitHub {
    owner = "projectcalico";
    repo = "calico";
    rev = "v${version}";
    hash = "sha256-w+dStKYbytNekl3HxBAek8kS+FC5Aeu7OEU4SIFLURY=";
  };
in mkGoTool pkgs {
  pname = "calicoctl";
  inherit version src;
  vendorHash = "sha256-J9X7W7UozsxNlXQwXYeDi++KkyjxwtnYvs4EkUq4Vec=";
  subPackages = [ "calicoctl/calicoctl" ];
  platforms = pkgs.lib.platforms.linux;
  description = "CLI for Calico network policy management";
  homepage = "https://www.tigera.io/project-calico/";
}
