# containerd — upstream container runtime
#
# Builds upstream containerd (NOT the k3s-io fork). Used for vanilla
# Kubernetes clusters. Builds containerd + containerd-shim-runc-v2.
{ pkgs, containerdVersion }:

let
  version = containerdVersion;
  src = pkgs.fetchFromGitHub {
    owner = "containerd";
    repo = "containerd";
    rev = "v${version}";
    hash = "sha256-P948Rn11kAENAX3qHrSmIdV6VgybbuHdOTAgcYWk2bg=";
  };
in pkgs.buildGoModule {
  pname = "containerd";
  inherit version src;

  vendorHash = null; # vendored in-tree

  buildInputs = [ pkgs.btrfs-progs ];

  subPackages = [
    "cmd/containerd"
    "cmd/containerd-shim-runc-v2"
    "cmd/ctr"
  ];

  ldflags = [
    "-s" "-w"
    "-X github.com/containerd/containerd/v2/version.Version=v${version}"
    "-X github.com/containerd/containerd/v2/version.Package=github.com/containerd/containerd/v2"
  ];

  doCheck = false;

  meta = {
    description = "An open and reliable container runtime";
    homepage = "https://containerd.io/";
    license = pkgs.lib.licenses.asl20;
    mainProgram = "containerd";
    platforms = pkgs.lib.platforms.linux;
  };
}
