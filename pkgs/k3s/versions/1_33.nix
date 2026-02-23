# k3s 1.33.8+k3s1 version pins
#
# Shared component versions come from lib/versions/kubernetes-1.33.nix.
# Hashes: use `nix build .#k3s-1-33` and fix hashes from error output.
let
  shared = import ../../../lib/versions/kubernetes-1.33.nix;
in {
  k3sVersion = "1.33.8+k3s1";
  k3sCommit = "0000000000000000000000000000000000000000";
  k3sRepoSha256 = "0000000000000000000000000000000000000000000000000000";
  k3sVendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

  k3sRootVersion = "0.15.0";
  k3sRootSha256 = "0000000000000000000000000000000000000000000000000000";

  # k3s uses rancher's forked CNI plugins
  k3sCNIVersion = "${shared.cniPluginsVersion}-k3s1";
  k3sCNISha256 = "0000000000000000000000000000000000000000000000000000";

  # k3s 1.33 uses containerd v2
  containerdVersion = "${shared.containerdVersion}-k3s1.33";
  containerdSha256 = "0000000000000000000000000000000000000000000000000000";
  containerdPackage = "github.com/k3s-io/containerd/v2";

  criCtlVersion = "${shared.crictlVersion}-k3s2";
  flannelVersion = "v0.28.0";
  flannelPluginVersion = "v${shared.cniPluginsVersion}-flannel1";
  kubeRouterVersion = "v2.6.3-k3s1";
  criDockerdVersion = "v0.3.19-k3s3";
  helmJobVersion = "v0.9.14-build20260210";

  chartVersions = {
    traefik-crd = {
      url = "https://k3s.io/k3s-charts/assets/traefik-crd/traefik-crd-38.0.201+up38.0.2.tgz";
      sha256 = "0000000000000000000000000000000000000000000000000000";
    };
    traefik = {
      url = "https://k3s.io/k3s-charts/assets/traefik/traefik-38.0.201+up38.0.2.tgz";
      sha256 = "0000000000000000000000000000000000000000000000000000";
    };
  };

  imagesVersions = builtins.fromJSON (builtins.readFile ./1_33-images.json);
}
