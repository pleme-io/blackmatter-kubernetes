# etcd server — distributed key-value store for Kubernetes
#
# Builds the etcd server binary for running as part of the control plane.
# The etcd CLI tools (etcdctl, etcdutl) are in pkgs/tools/etcd.nix.
# Source hashes shared via etcd-hashes.nix.
{ mkRuntimeComponent, etcdVersion }:

mkRuntimeComponent {
  pname = "etcd-server";
  version = etcdVersion;
  owner = "etcd-io";
  repo = "etcd";
  hashes = import ./etcd-hashes.nix;
  vendorHashes = {
    "3.5.15" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    "3.5.24" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    "3.6.7" = "sha256-hUFUcoXaOKTkoJ7YUwljpg7EZRhXi5tXcE2bteVRBE0=";
  };
  modRoot = "server";
  env = { CGO_ENABLED = "0"; };
  ldflags = [
    "-s" "-w"
    "-X=go.etcd.io/etcd/api/v3/version.GitSHA=v${etcdVersion}"
  ];
  description = "etcd distributed key-value store (server)";
  homepage = "https://etcd.io/";
  mainProgram = "etcd";
}
