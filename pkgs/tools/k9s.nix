# K9s — Kubernetes TUI dashboard
{ mkGoTool, pkgs }:

let
  version = "0.50.18";
  src = pkgs.fetchFromGitHub {
    owner = "derailed";
    repo = "k9s";
    tag = "v${version}";
    hash = "sha256-WIcT4LfoIZ8BctwrUgn+mLbqwJ2NZx6Sc5sJeT9fsus=";
  };
in mkGoTool pkgs {
  pname = "k9s";
  inherit version src;
  vendorHash = "sha256-QvMT/pHtwXAsbGxcOLwqYQoa2gdplhDUnPhwc/50PFs=";
  proxyVendor = true;
  tags = [ "netcgo" ];
  versionLdflags = {
    "github.com/derailed/k9s/cmd.version" = version;
    "github.com/derailed/k9s/cmd.commit" = src.rev or "v${version}";
    "github.com/derailed/k9s/cmd.date" = "1970-01-01T00:00:00Z";
  };
  completions = { install = true; command = "k9s"; };
  extraPostInstall = ''
    mkdir -p $out/share/k9s/skins
    cp -r $src/skins/* $out/share/k9s/skins/ 2>/dev/null || true
  '';
  description = "Kubernetes TUI dashboard";
  homepage = "https://k9scli.io/";
}
