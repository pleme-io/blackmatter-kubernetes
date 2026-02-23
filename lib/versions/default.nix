# Shared Kubernetes version registry
#
# Single source of truth for component versions across k3s and vanilla k8s.
# Bumping a version here updates both distributions simultaneously.
#
# Tracks:
#   1.30 — EOL (2025-06-28)
#   1.31 — EOL (2025-10-28)
#   1.32 — EOL (2026-02-28)
#   1.33 — Supported
#   1.34 — Supported (default)
#   1.35 — Current (latest)
{
  "1.30" = import ./kubernetes-1.30.nix;
  "1.31" = import ./kubernetes-1.31.nix;
  "1.32" = import ./kubernetes-1.32.nix;
  "1.33" = import ./kubernetes-1.33.nix;
  "1.34" = import ./kubernetes-1.34.nix;
  "1.35" = import ./kubernetes-1.35.nix;
}
