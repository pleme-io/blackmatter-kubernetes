# Kubernetes monorepo source factory
#
# Thin wrapper around substrate's mkGoMonorepoSource, specialized for
# the kubernetes/kubernetes repository.
#
# Usage:
#   mkSource = import ./source.nix { inherit mkGoMonorepoSource pkgs; };
#   k8s = mkSource {
#     versions = import ../../lib/versions/kubernetes-1.34.nix;
#     hashes = import ./versions/1_34.nix;
#   };
#   # k8s.src, k8s.version, k8s.ldflags
{ mkGoMonorepoSource, pkgs }:

{ versions, hashes }:

mkGoMonorepoSource pkgs {
  owner = "kubernetes";
  repo = "kubernetes";
  version = versions.kubernetesVersion;
  srcHash = hashes.srcHash;
  versionPackage = "k8s.io/component-base/version";
}
