# Shared Kubernetes version registry
#
# Single source of truth for component versions across k3s and vanilla k8s.
# Bumping a version here updates both distributions simultaneously.
{
  "1.34" = import ./kubernetes-1.34.nix;
  "1.35" = import ./kubernetes-1.35.nix;
}
