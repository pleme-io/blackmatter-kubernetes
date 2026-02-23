# CNI Plugins — upstream standard container networking interface plugins
#
# These are the vanilla upstream CNI plugins (NOT the rancher/k3s fork).
# Used for vanilla Kubernetes. Version comes from the shared version registry.
{ pkgs, cniPluginsVersion }:

let
  version = cniPluginsVersion;

  # Hash map per CNI version
  hashes = {
    "1.8.0" = "sha256-/I2fEVVQ89y8l95Ri0V5qxVj/SzXVqP0IT2vSdz8jC8=";
    "1.9.0" = "sha256-0ZonR8pV20bBbC2AkNCJhoseDVxNwwMa7coD/ON6clA=";
  };
in pkgs.buildGoModule {
  pname = "cni-plugins";
  inherit version;

  src = pkgs.fetchFromGitHub {
    owner = "containernetworking";
    repo = "plugins";
    rev = "v${version}";
    hash = hashes.${version};
  };

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
