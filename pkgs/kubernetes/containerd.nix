# containerd — upstream container runtime
#
# Builds upstream containerd (NOT the k3s-io fork). Used for vanilla
# Kubernetes clusters. Builds containerd + containerd-shim-runc-v2.
{ mkRuntimeComponent, containerdVersion, pkgs }:

mkRuntimeComponent {
  pname = "containerd";
  version = containerdVersion;
  owner = "containerd";
  repo = "containerd";
  hashes = {
    "1.7.27" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    "2.1.5" = "sha256-P948Rn11kAENAX3qHrSmIdV6VgybbuHdOTAgcYWk2bg=";
  };
  vendorHash = null;
  buildInputs = [ pkgs.btrfs-progs ];
  subPackages = [
    "cmd/containerd"
    "cmd/containerd-shim-runc-v2"
    "cmd/ctr"
  ];
  ldflags = [
    "-s" "-w"
    "-X github.com/containerd/containerd/v2/version.Version=v${containerdVersion}"
    "-X github.com/containerd/containerd/v2/version.Package=github.com/containerd/containerd/v2"
  ];
  description = "An open and reliable container runtime";
  homepage = "https://containerd.io/";
}
