# etcd tools — etcdctl and etcdutl built from the etcd monorepo
#
# Version sourced from shared registry (lib/versions/) to stay in sync with
# the etcd server in pkgs/kubernetes/etcd.nix. Source hash must match since
# both fetch the same owner/repo/rev.
{ pkgs }:
let
  # Use latest track version from shared registry
  versionRegistry = import ../../lib/versions;
  version = versionRegistry."1.35".etcdVersion;

  src = pkgs.fetchFromGitHub {
    owner = "etcd-io";
    repo = "etcd";
    rev = "v${version}";
    # Shared with pkgs/kubernetes/etcd.nix (same repo + rev = same hash)
    hash = (import ../kubernetes/etcd-hashes.nix).${version};
  };

  etcdctl = pkgs.buildGoModule {
    pname = "etcdctl";
    inherit version src;
    modRoot = "etcdctl";
    vendorHash = "sha256-jN+oNoIxNYM2Wm3s+/zDyacyXxVWaHl9t7sot8PL9xk=";
    env.CGO_ENABLED = "0";
    ldflags = [ "-s" "-w" "-X=go.etcd.io/etcd/api/v3/version.GitSHA=v${version}" ];
    doCheck = false;
    meta = {
      description = "etcdctl — CLI for etcd";
      homepage = "https://etcd.io/";
      license = pkgs.lib.licenses.asl20;
      mainProgram = "etcdctl";
    };
  };

  etcdutl = pkgs.buildGoModule {
    pname = "etcdutl";
    inherit version src;
    modRoot = "etcdutl";
    vendorHash = "sha256-A2rYstzlBlS3ta5yJVP/RTjgBz+9Y0I79ITr77GrqOo=";
    env.CGO_ENABLED = "0";
    ldflags = [ "-s" "-w" "-X=go.etcd.io/etcd/api/v3/version.GitSHA=v${version}" ];
    doCheck = false;
    meta = {
      description = "etcdutl — offline etcd data utilities";
      homepage = "https://etcd.io/";
      license = pkgs.lib.licenses.asl20;
      mainProgram = "etcdutl";
    };
  };
in pkgs.symlinkJoin {
  name = "etcd-tools-${version}";
  paths = [ etcdctl etcdutl ];
  meta = {
    description = "etcd CLI tools (etcdctl + etcdutl)";
    homepage = "https://etcd.io/";
    license = pkgs.lib.licenses.asl20;
  };
}
