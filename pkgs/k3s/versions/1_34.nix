# k3s 1.34.3+k3s1 version pins
#
# Shared component versions (kubernetesVersion, etcdVersion, containerdVersion,
# runcVersion, cniPluginsVersion, crictlVersion) come from the version registry
# at lib/versions/. K3s-specific fields (commit, forks, charts) stay here.
let
  shared = import ../../../lib/versions/kubernetes-1.34.nix;
in {
  k3sVersion = "1.34.3+k3s1";
  k3sCommit = "48ffa7b6893f21b919b3029d54c9d9838ae426a1";
  k3sRepoSha256 = "1177kzbhp6ihb7dzfdi1a0idgp69y1hwh6wnwvdx1fnivg2gj7aw";
  k3sVendorHash = "sha256-dp8SU24nuy3WmG1Zln/J2nVHnVQmVyN78FBOSxNjbF8=";

  k3sRootVersion = "0.15.0";
  k3sRootSha256 = "008n8xx7x36y9y4r24hx39xagf1dxbp3pqq2j53s9zkaiqc62hd0";

  # k3s uses rancher's forked CNI plugins, version tracks shared.cniPluginsVersion
  k3sCNIVersion = "${shared.cniPluginsVersion}-k3s1";
  k3sCNISha256 = "04xig5spp81l81781ixmk99ghiz8lk0p16zhcbja5mslfdjmc7vg";

  # k3s uses k3s-io fork of containerd, version tracks shared.containerdVersion
  containerdVersion = "${shared.containerdVersion}-k3s1";
  containerdSha256 = "0n0g58d352i8wz0bqn87vgrd7z54j268cbmbp19fz68wmifm7fl8";
  containerdPackage = "github.com/k3s-io/containerd/v2";

  criCtlVersion = "${shared.crictlVersion}-k3s2";
  flannelVersion = "v0.27.4";
  flannelPluginVersion = "v${shared.cniPluginsVersion}-flannel1";
  kubeRouterVersion = "v2.6.3-k3s1";
  criDockerdVersion = "v0.3.19-k3s3";
  helmJobVersion = "v0.9.12-build20251215";

  chartVersions = {
    traefik-crd = {
      url = "https://k3s.io/k3s-charts/assets/traefik-crd/traefik-crd-37.1.1+up37.1.0.tgz";
      sha256 = "0q568ffjhxmw87fzwafxlxrzx2lgcqlqbwj87pbc2xszh9pyakyd";
    };
    traefik = {
      url = "https://k3s.io/k3s-charts/assets/traefik/traefik-37.1.1+up37.1.0.tgz";
      sha256 = "0gpcr6zfbncvp2sjjwzg732k4xfr5ba0pbc5x08lgwvibqpp4r27";
    };
  };

  imagesVersions = builtins.fromJSON (builtins.readFile ./1_34-images.json);
}
