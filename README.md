# blackmatter-kubernetes

Nix-native Kubernetes distribution and tooling layer. Builds k3s and vanilla Kubernetes
control plane components from source using an upstream Go toolchain, provides 60+ CLI tools
as reproducible Nix packages, and ships NixOS modules for declarative cluster management
with profile-based CNI and security presets. All packages are prefixed `blackmatter-` in
the overlay to avoid collisions with nixpkgs.

## Architecture

```
flake.nix
  |
  +-- lib/
  |     profiles.nix          8 cluster profiles (flannel, calico, cilium, istio)
  |     versions/              Per-track version registry (k8s 1.30 - 1.35)
  |     kubernetes-base.nix    Shared kernel/sysctl/firewall helpers
  |     distributions.nix      Distribution metadata
  |
  +-- pkgs/
  |     k3s/                   k3s builds (3-stage Go: CNI -> bundle+containerd -> binary)
  |     kubernetes/            Vanilla k8s (kubelet, kubeadm, apiserver, scheduler, etc.)
  |     tools/                 Core CLI (kubectl, helm, k9s, fluxcd, stern, etc.)
  |     network/               CNI plugins (flannel, calico, cilium, multus, istioctl, linkerd)
  |     security/              Security tools (kubeseal, trivy, grype, cosign, kyverno, etc.)
  |     cluster/               Cluster management (clusterctl, talosctl, vcluster, crossplane)
  |     gitops/                GitOps & CD (argocd, tektoncd-cli, argo-rollouts, timoni, kapp)
  |     plugins/               kubectl plugins (popeye, kubent, pluto, kor, krew, etc.)
  |     observability/         Observability (thanos, logcli, tempo-cli, coredns, etc.)
  |     testing/               Load testing (k6, vegeta, hey, fortio)
  |
  +-- module/
  |     home-manager/          HM module: tool profiles, shell aliases, kubeconfig mgmt
  |     nixos/k3s/             NixOS k3s module (server/agent, HA, profiles)
  |     nixos/kubernetes/      NixOS vanilla k8s module (control-plane/worker, kubeadm)
  |     nixos/fluxcd/          NixOS FluxCD module
  |     nixos/kubectl/         NixOS kubectl module
  |
  +-- tests/
        unit/                  80 pure Nix eval tests (no VMs, instant)
        integration/           NixOS VM tests (single-node, multi-node, HA)
```

## Features

- **k3s from source** -- tracks 1.30 through 1.35 built via a 3-stage Go pipeline
- **Vanilla Kubernetes from source** -- kubelet, kubeadm, apiserver, scheduler, proxy, etcd, containerd, runc, crictl, CNI plugins across all tracks
- **60+ cross-platform CLI tools** -- kubectl, helm, k9s, fluxcd, stern, kubecolor, kustomize, helmfile, argocd, and many more
- **8 cluster profiles** -- flannel-minimal, flannel-standard, flannel-production, calico-standard, calico-hardened, cilium-standard, cilium-mesh, istio-mesh
- **Version track system** -- shared version registry ensures k3s and vanilla k8s use identical component versions per track
- **NixOS modules** -- declarative k3s and vanilla k8s service configuration with profile support, firewall, kernel modules, NVIDIA runtime
- **Home-manager module** -- three tool profiles (minimal, standard, full) with per-tool overrides, shell aliases, kubeconfig management
- **Overlay** -- all packages exposed as `pkgs.blackmatter-<name>` with nixpkgs fallback
- **Comprehensive tests** -- 80 unit tests (pure Nix eval) plus NixOS VM integration tests

## Installation

Add as a flake input:

```nix
{
  inputs = {
    blackmatter-kubernetes = {
      url = "github:pleme-io/blackmatter-kubernetes";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.substrate.follows = "substrate";
      inputs.blackmatter-go.follows = "blackmatter-go";
    };
  };
}
```

### Home-manager (tool installation)

```nix
{
  imports = [ inputs.blackmatter-kubernetes.homeManagerModules.default ];

  blackmatter.components.kubernetes = {
    enable = true;
    profile = "standard";  # minimal | standard | full
  };
}
```

### NixOS (k3s cluster)

```nix
{
  imports = [ inputs.blackmatter-kubernetes.nixosModules.k3s ];

  services.blackmatter.k3s = {
    enable = true;
    role = "server";
    distribution = "1.34";
    profile = "cilium-standard";
  };
}
```

### NixOS (vanilla Kubernetes)

```nix
{
  imports = [ inputs.blackmatter-kubernetes.nixosModules.kubernetes ];

  services.blackmatter.kubernetes = {
    enable = true;
    role = "control-plane";
    distribution = "1.34";
    profile = "flannel-standard";
  };
}
```

## Cluster Profiles

Profiles are pre-canned configurations that set CNI, disable flags, firewall rules,
kernel modules, and extra packages. All profile-set values use `mkDefault` so they
can be overridden individually.

| Profile | CNI | Use Case |
|---------|-----|----------|
| `flannel-minimal` | Flannel | Dev, CI, edge/IoT, learning |
| `flannel-standard` | Flannel | Dev, staging, small production |
| `flannel-production` | Flannel | Production without advanced networking |
| `calico-standard` | Calico | Multi-tenant staging/production, hybrid cloud |
| `calico-hardened` | Calico | Regulated production (PCI-DSS, SOC2) |
| `cilium-standard` | Cilium (eBPF) | Production with eBPF performance |
| `cilium-mesh` | Cilium (eBPF) | Microservices, zero-trust networking |
| `istio-mesh` | Flannel + Istio | Enterprise service mesh, mTLS-everywhere |

## Home-Manager Tool Profiles

| Profile | Tools |
|---------|-------|
| `minimal` | kubectl, helm, k9s, kubectx |
| `standard` | minimal + fluxcd, stern, kubecolor, kube-score, kubectl-tree, helmfile, kustomize, kubeseal, kubeconform, popeye, pluto, kubent, kor |
| `full` | All 60+ cross-platform tools |

Override individual tools regardless of profile:

```nix
blackmatter.components.kubernetes = {
  enable = true;
  profile = "standard";
  tools = {
    trivy.enable = true;     # Add trivy to standard
    kubeseal.enable = false;  # Remove kubeseal from standard
  };
};
```

## Version Tracks

The version registry at `lib/versions/` pins component versions per Kubernetes minor release:

| Track | Kubernetes | etcd | containerd | runc |
|-------|-----------|------|------------|------|
| 1.34 (default) | 1.34.3 | 3.6.7 | 2.1.5 | 1.2.6 |
| 1.35 (latest) | 1.35.x | 3.6.x | 2.1.x | 1.2.x |

Both k3s and vanilla Kubernetes consume the same version registry, ensuring parity.

## Development

### Build from source

```bash
# Build kubectl (default package)
nix build .#kubectl

# Build a specific tool
nix build .#helm
nix build .#k9s
nix build .#fluxcd

# Build k3s (Linux only)
nix build .#k3s
nix build .#k3s-1-35  # Specific track

# Build vanilla k8s components (Linux only)
nix build .#kubelet
nix build .#kubeadm
nix build .#kube-apiserver
```

### Run tests

```bash
# Unit tests (pure Nix eval, instant)
nix eval .#tests.x86_64-linux.unit

# Home-manager module tests
nix eval .#tests.x86_64-linux.hm-module

# Integration tests (NixOS VMs, requires x86_64-linux)
nix build .#checks.x86_64-linux.single-node
nix build .#checks.x86_64-linux.multi-node
nix build .#checks.x86_64-linux.ha-server

# Latest track integration
nix build .#checks.x86_64-linux.single-node-latest

# Profile integration
nix build .#checks.x86_64-linux.single-node-flannel-minimal

# Vanilla k8s integration
nix build .#checks.x86_64-linux.k8s-single-node

# Profile evaluation checks
nix build .#checks.x86_64-linux.profile-eval
nix build .#checks.x86_64-linux.k8s-profile-eval
```

## Project Structure

```
blackmatter-kubernetes/
  flake.nix                    Flake entry point, overlay, package exports
  lib/
    profiles.nix               8 cluster profile definitions
    versions/                  Per-track component version pins (1.30 - 1.35)
    kubernetes-base.nix        Shared kernel, sysctl, firewall, DNS check helpers
    distributions.nix          Distribution metadata
  pkgs/
    k3s/                       k3s multi-track build (builder.nix + per-track versions)
    kubernetes/                Vanilla k8s monorepo build (kubelet, kubeadm, apiserver...)
    tools/                     23 core CLI tools built from Go source
    network/                   10 network/CNI packages (flannel, calico, cilium, istio, linkerd)
    security/                  Security scanning and policy tools
    cluster/                   Cluster lifecycle management tools
    gitops/                    GitOps and continuous delivery tools
    plugins/                   kubectl plugins and extensions
    observability/             Monitoring and observability tools
    testing/                   Load testing tools
  module/
    home-manager/              Cross-platform HM module (profiles, aliases, kubeconfig)
    nixos/k3s/                 NixOS k3s module (systemd service, profiles, HA)
    nixos/kubernetes/          NixOS vanilla k8s module (control-plane, kubelet, etcd, certs)
    nixos/fluxcd/              NixOS FluxCD module
    nixos/kubectl/             NixOS kubectl module
  tests/
    unit/                      80 pure Nix evaluation tests
    integration/               NixOS VM tests (single-node, multi-node, HA)
```

## Related Projects

- [substrate](https://github.com/pleme-io/substrate) -- Reusable Nix build patterns (Go toolchain, monorepo builders, test helpers)
- [blackmatter-go](https://github.com/pleme-io/blackmatter-go) -- Go toolchain overlay (Go 1.25.6 built from source)
- [blackmatter](https://github.com/pleme-io/blackmatter) -- Home-manager/nix-darwin module aggregator
- [k8s](https://github.com/pleme-io/k8s) -- GitOps manifests for the pleme-io K3s cluster (FluxCD)

## License

MIT
