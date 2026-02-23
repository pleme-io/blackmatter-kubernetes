# k3s 1.35.1+k3s1 version pins
#
# Shared component versions come from lib/versions/kubernetes-1.35.nix.
# Hashes: use `nix build .#k3s-latest` and fix hashes from error output.
let
  shared = import ../../../lib/versions/kubernetes-1.35.nix;
in {
  k3sVersion = "1.35.1+k3s1";
  k3sCommit = "50fa2d70c239b3984dab99a2fb1ddaa35c3f2051";
  k3sRepoSha256 = "0000000000000000000000000000000000000000000000000000";
  k3sVendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

  k3sRootVersion = "0.15.0";
  k3sRootSha256 = "008n8xx7x36y9y4r24hx39xagf1dxbp3pqq2j53s9zkaiqc62hd0";

  # k3s uses rancher's forked CNI plugins
  k3sCNIVersion = "${shared.cniPluginsVersion}-k3s1";
  k3sCNISha256 = "0000000000000000000000000000000000000000000000000000";

  # k3s uses k3s-io fork of containerd
  containerdVersion = "${shared.containerdVersion}-k3s1";
  containerdSha256 = "0n0g58d352i8wz0bqn87vgrd7z54j268cbmbp19fz68wmifm7fl8";
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

  imagesVersions = builtins.fromJSON (builtins.readFile ./1_35-images.json);
}
