# Flannel CNI Plugin — CNI plugin for flannel network
{ mkGoTool, pkgs }:

let
  version = "1.9.0-flannel1";
  src = pkgs.fetchFromGitHub {
    owner = "flannel-io";
    repo = "cni-plugin";
    rev = "v${version}";
    sha256 = "sha256-skYbIU1uqfEiXDEG5N0QVbMH/8X9MIJRH7XoXq5zA7w=";
  };
in mkGoTool pkgs {
  pname = "cni-plugin-flannel";
  inherit version src;
  vendorHash = "sha256-hn4NT/fXu7bremIpYPSva/Od97LiVuHE7+8jgpLMaRs=";
  ldflags = [
    "-s" "-w"
    "-X main.Version=${version}"
    "-X main.Commit=${version}"
    "-X main.Program=flannel"
  ];
  extraPostInstall = ''
    mv $out/bin/cni-plugin $out/bin/flannel 2>/dev/null || true
  '';
  platforms = pkgs.lib.platforms.linux;
  description = "Flannel CNI plugin";
  homepage = "https://github.com/flannel-io/cni-plugin";
}
