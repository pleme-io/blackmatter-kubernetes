# etcd server — distributed key-value store for Kubernetes
#
# Builds the etcd server binary for running as part of the control plane.
# The etcd CLI tools (etcdctl, etcdutl) are in pkgs/tools/etcd.nix.
{ pkgs, etcdVersion }:

let
  version = etcdVersion;

  # Hash map per etcd version (placeholder hashes for untested versions)
  hashes = {
    "3.5.15" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    "3.5.24" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    "3.6.7" = "sha256-i8VZlK76OQQeojKHo9sdkyNR0Hdiofx0TLUDWKiXOTU=";
  };

  src = pkgs.fetchFromGitHub {
    owner = "etcd-io";
    repo = "etcd";
    rev = "v${version}";
    hash = hashes.${version};
  };
in pkgs.buildGoModule {
  pname = "etcd-server";
  inherit version src;

  modRoot = "server";
  vendorHash = {
    "3.5.15" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    "3.5.24" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    "3.6.7" = "sha256-hUFUcoXaOKTkoJ7YUwljpg7EZRhXi5tXcE2bteVRBE0=";
  }.${version};

  env.CGO_ENABLED = "0";

  ldflags = [
    "-s" "-w"
    "-X=go.etcd.io/etcd/api/v3/version.GitSHA=v${version}"
  ];

  doCheck = false;

  meta = {
    description = "etcd distributed key-value store (server)";
    homepage = "https://etcd.io/";
    license = pkgs.lib.licenses.asl20;
    mainProgram = "etcd";
    platforms = pkgs.lib.platforms.linux;
  };
}
