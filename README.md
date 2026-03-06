# blackmatter-kubernetes

Kubernetes tooling, cluster management, and from-source builds for k3s + vanilla k8s.

## Overview

Comprehensive Kubernetes module providing 60+ CLI tools, k3s (multi-track: 1.30-1.35), vanilla Kubernetes control plane components, and NixOS service modules. All Go binaries are built from source using the blackmatter-go toolchain. Tools are prefixed `blackmatter-*` in the overlay. Includes 8 network profiles (flannel, calico, cilium, istio) and VM-based integration tests.

## Flake Outputs

- `homeManagerModules.default` -- cross-platform HM module for K8s tools
- `nixosModules.k3s` -- k3s NixOS service at `services.blackmatter.k3s`
- `nixosModules.kubernetes` -- vanilla k8s NixOS service at `services.blackmatter.kubernetes`
- `nixosModules.kubectl`, `nixosModules.fluxcd` -- standalone NixOS modules
- `overlays.default` -- all tools + k3s/k8s versioned packages
- `packages.<system>.*` -- 60+ individual tool packages
- `checks.x86_64-linux.*` -- VM integration tests (single-node, multi-node, HA)

## Usage

```nix
{
  inputs.blackmatter-kubernetes.url = "github:pleme-io/blackmatter-kubernetes";
}
```

```nix
# Home-manager (cross-platform tools)
imports = [ inputs.blackmatter-kubernetes.homeManagerModules.default ];

# NixOS (k3s cluster)
services.blackmatter.k3s = {
  enable = true;
  profile = "flannel-standard";
};
```

## Key Tool Categories

- **Core:** kubectl, helm, k9s, fluxcd, kustomize, stern
- **Security:** trivy, grype, kubeseal, kyverno, cosign, kubescape
- **Cluster:** clusterctl, talosctl, vcluster, velero
- **GitOps:** argocd, tektoncd-cli, timoni, kapp
- **Network:** flannel, calico, cilium-cli, istioctl, linkerd
- **Observability:** thanos, logcli, tempo-cli, kube-state-metrics
- **Testing:** k6, vegeta, hey, fortio

## Structure

- `pkgs/tools/`, `pkgs/network/`, `pkgs/security/`, etc. -- tool derivations
- `pkgs/k3s/` -- multi-track k3s builds
- `pkgs/kubernetes/` -- vanilla k8s monorepo builds
- `module/home-manager/` -- HM module
- `module/nixos/` -- NixOS service modules
- `tests/` -- unit + integration tests
- `lib/profiles.nix` -- network profile definitions
