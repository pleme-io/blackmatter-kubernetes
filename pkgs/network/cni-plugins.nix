# CNI Plugins — standard container networking interface plugins
#
# 18 plugins across IPAM, Main, and Meta categories.
# Not using mkGoTool because of the large number of subPackages.
{ pkgs }:

let
  version = "1.9.0";
  src = pkgs.fetchFromGitHub {
    owner = "containernetworking";
    repo = "plugins";
    rev = "v${version}";
    hash = "sha256-0ZonR8pV20bBbC2AkNCJhoseDVxNwwMa7coD/ON6clA=";
  };
in pkgs.buildGoModule {
  pname = "cni-plugins";
  inherit version src;

  vendorHash = null; # vendored in-tree

  subPackages = [
    # IPAM
    "plugins/ipam/dhcp"
    "plugins/ipam/host-local"
    "plugins/ipam/static"
    # Main
    "plugins/main/bridge"
    "plugins/main/dummy"
    "plugins/main/host-device"
    "plugins/main/ipvlan"
    "plugins/main/loopback"
    "plugins/main/macvlan"
    "plugins/main/ptp"
    "plugins/main/tap"
    "plugins/main/vlan"
    # Meta
    "plugins/meta/bandwidth"
    "plugins/meta/firewall"
    "plugins/meta/portmap"
    "plugins/meta/sbr"
    "plugins/meta/tuning"
    "plugins/meta/vrf"
  ];

  ldflags = [
    "-X github.com/containernetworking/plugins/pkg/utils/buildversion.BuildVersion=v${version}"
  ];

  doCheck = false;

  meta = {
    description = "Standard CNI network plugins";
    homepage = "https://www.cni.dev/";
    license = pkgs.lib.licenses.asl20;
    platforms = pkgs.lib.platforms.linux;
  };
}
