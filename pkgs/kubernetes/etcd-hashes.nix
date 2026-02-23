# Shared etcd source hashes (fetchFromGitHub)
#
# Single source of truth for etcd-io/etcd source hashes.
# Consumed by:
#   - pkgs/kubernetes/etcd.nix (server, via mkRuntimeComponent)
#   - pkgs/tools/etcd.nix (etcdctl + etcdutl)
{
  "3.5.15" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  "3.5.24" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  "3.6.7"  = "sha256-i8VZlK76OQQeojKHo9sdkyNR0Hdiofx0TLUDWKiXOTU=";
}
