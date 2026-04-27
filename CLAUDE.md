# blackmatter-kubernetes

> **★★★ CSE / Knowable Construction.** This repo operates under **Constructive Substrate Engineering** — canonical specification at [`pleme-io/theory/CONSTRUCTIVE-SUBSTRATE-ENGINEERING.md`](https://github.com/pleme-io/theory/blob/main/CONSTRUCTIVE-SUBSTRATE-ENGINEERING.md). The Compounding Directive (operational rules: solve once, load-bearing fixes only, idiom-first, models stay current, direction beats velocity) is in the org-level pleme-io/CLAUDE.md ★★★ section. Read both before non-trivial changes.


NixOS modules for K3s and vanilla Kubernetes with a profile system, plus a
cross-platform home-manager module for CLI tools. Consumed by the `nix` repo
as `inputs.blackmatter-kubernetes`.

## Key Concepts

- **Profile system** -- 8 pre-canned cluster configurations (CNI, firewall, kernel modules)
  set via `services.blackmatter.k3s.profile`. All profile values use `mkDefault` so
  the user can still override individually.
- **Distribution tracks** -- K3s and vanilla K8s binaries built for tracks 1.30 through
  1.35. Default track: 1.34, latest: 1.35. Package naming: `blackmatter-k3s-1-34`,
  `blackmatter-kubectl-1-35`, etc.
- **Dual-sentinel roleConditionPath** -- race-free server/agent role selection via
  systemd `ConditionPathExists` (see below).
- **kubernetes-base.nix** -- shared constants, option schemas, and config fragments
  consumed by both the k3s and vanilla k8s modules.

## File Structure

```
flake.nix                         -- flake: overlays, nixosModules, homeManagerModules, packages, checks
lib/
  profiles.nix                    -- 8 cluster profile definitions (mkProfile)
  kubernetes-base.nix             -- shared kernel, sysctl, firewall, DNS-check helpers
module/
  nixos/
    k3s/default.nix               -- services.blackmatter.k3s (k3s server + agent)
    kubernetes/                   -- services.blackmatter.kubernetes (vanilla k8s)
      default.nix, kubelet.nix, control-plane.nix, etcd.nix, kubeadm.nix, certs.nix
    kubectl/default.nix           -- kubectl path module
    fluxcd/default.nix            -- FluxCD systemd service
  home-manager/                   -- cross-platform HM module (k9s, kikai, kubectl, etc.)
pkgs/
  k3s/                            -- per-track k3s package builds
  kubernetes/                     -- per-track vanilla k8s component builds
  tools/ network/ security/       -- Go-based CLI tools (mkGoTool)
  cluster/ gitops/ plugins/
  observability/ testing/
tests/
  unit/                           -- nix eval .#tests.<system>.unit
  integration/                    -- nix build .#checks.x86_64-linux.single-node (NixOS VM tests)
kikai/                            -- kikai cluster lifecycle orchestrator (Rust, separate flake input)
```

## NixOS Module: `services.blackmatter.k3s`

### Core Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable k3s |
| `role` | enum | `"server"` | `server` (control plane) or `agent` (worker) |
| `distribution` | enum | `"1.34"` | K8s track (1.30-1.35), selects `blackmatter-k3s-<track>` |
| `package` | package | auto | Auto-selected from distribution track |
| `profile` | nullOr enum | null | Cluster profile name (see profiles below) |
| `configPath` | nullOr path | null | Path to k3s YAML config file (`--config`) |
| `serverAddr` | str | `""` | URL of k3s server to join (required for agents and HA) |
| `token` / `tokenFile` | str / path | | Cluster join token (file preferred) |
| `agentToken` / `agentTokenFile` | str / path | | Agent-specific join token |
| `clusterInit` | bool | false | Initialize HA with embedded etcd (first server only) |
| `disable` | listOf str | `[]` | Components to disable (traefik, servicelb, etc.) |
| `disableAgent` | bool | false | Run server without kubelet (control plane only) |
| `nodeName` | nullOr str | null | Node name override |
| `nodeLabel` | listOf str | `[]` | Labels to apply |
| `nodeTaint` | listOf str | `[]` | Taints to apply |
| `nodeIP` | nullOr str | null | IP address to advertise |
| `dataDir` | str | `/var/lib/rancher/k3s` | Data directory |
| `clusterCIDR` | str | `10.42.0.0/16` | Pod network CIDR |
| `serviceCIDR` | str | `10.43.0.0/16` | Service network CIDR |
| `clusterDNS` | str | `10.43.0.10` | Cluster DNS IP |
| `extraFlags` | listOf str | `[]` | Additional CLI flags |
| `environmentFile` | nullOr path | null | Systemd `EnvironmentFile` |
| `manifests` | attrsOf { content } | `{}` | Auto-deploy YAML manifests |
| `images` | listOf package | `[]` | Pre-provisioned container images |
| `firewall.*` | | | `enable`, `apiServerPort`, `extraTCPPorts`, `extraUDPPorts`, `trustedInterfaces` |
| `kernel.*` | | | `enable`, `extraModules` |
| `waitForDNS.*` | | | `enable`, `timeout` (DNS pre-check before start) |
| `nvidia.enable` | bool | false | Configure NVIDIA containerd runtime |
| `gracefulNodeShutdown.enable` | bool | false | Enable graceful shutdown |

### `agent.enable` -- K3s Agent Service

When `agent.enable = true`, the module creates a second systemd unit
`k3s-agent.service` in addition to the primary `k3s.service`. Key properties:

- `After = [ "network-online.target" "kindling-init.service" ]`
- `Conflicts = [ "k3s.service" ]` -- mutually exclusive with server
- Uses `k3s agent` with `--config` from `configPath` (if set)
- Only added to `wantedBy = [ "multi-user.target" ]` when `roleConditionPath`
  is also set (otherwise it must be started explicitly)

### `roleConditionPath` -- Dual-Sentinel Pattern

This option solves the problem of building a single AMI that can boot as
either a K3s server or agent, without races or runtime `systemctl mask/enable`
commands.

```nix
services.blackmatter.k3s = {
  enable = true;
  agent.enable = true;
  roleConditionPath = {
    server = "/var/lib/kindling/server-mode";
    agent  = "/var/lib/kindling/agent-mode";
  };
};
```

**How it works:**

1. Both `k3s.service` and `k3s-agent.service` are in
   `wantedBy = [ "multi-user.target" ]` -- systemd will attempt to start both
   on every boot.

2. Each service has a `ConditionPathExists` in its `[Unit]` section:
   - `k3s.service` -- `ConditionPathExists=/var/lib/kindling/server-mode`
   - `k3s-agent.service` -- `ConditionPathExists=/var/lib/kindling/agent-mode`

3. Systemd evaluates conditions at **execution time**, after all ordering
   dependencies (`After=`) are satisfied.

4. An init service (e.g., `kindling-init.service`, ordered `Before=` both K3s
   units) creates exactly **one** sentinel file based on instance metadata,
   tags, or userdata.

5. The service whose sentinel exists starts; the other skips silently.

6. During AMI builds, **neither** sentinel exists, so neither service starts --
   no masking, no cleanup, no race conditions.

**Why this replaces `systemctl mask/enable`:**

- `mask/enable` requires runtime shell commands, which race with systemd
  target activation.
- `ConditionPathExists` is evaluated by systemd itself, atomically, after
  ordering constraints are satisfied.
- The init service creates the sentinel file in its `ExecStart`, which
  completes before systemd evaluates the K3s conditions (due to `After=`
  ordering).

### Integration with kindling-init.service

The `k3s-agent.service` declares `After = [ ... "kindling-init.service" ]`.
The kindling-init service (from the `kindling` repo) processes userdata,
writes sentinel files, and configures node identity before K3s starts.
The ordering ensures:

```
kindling-init.service (writes sentinel + config)
  -> k3s.service        (starts if server sentinel exists)
  -> k3s-agent.service  (starts if agent sentinel exists)
```

## Cluster Profiles

Set via `services.blackmatter.k3s.profile` (or `services.blackmatter.kubernetes.profile`).

| Profile | CNI | Use Case | Disables |
|---------|-----|----------|----------|
| `flannel-minimal` | flannel | Dev, CI, edge/IoT | traefik, servicelb, metrics-server, local-storage |
| `flannel-standard` | flannel | Dev, staging, small prod | (none) |
| `flannel-production` | flannel | Prod without advanced networking | (none) + kyverno, trivy |
| `calico-standard` | calico | Multi-tenant, hybrid cloud | servicelb; flannel-backend=none |
| `calico-hardened` | calico | PCI-DSS, SOC2, regulated | servicelb; protect-kernel-defaults |
| `cilium-standard` | cilium (eBPF) | Prod with eBPF performance | servicelb; disable-kube-proxy |
| `cilium-mesh` | cilium (eBPF) | Microservices, zero-trust | traefik, servicelb; disable-kube-proxy |
| `istio-mesh` | flannel + Istio | Enterprise service mesh | traefik |

Profiles set `disable`, `extraFlags`, `firewall.*`, and `kernel.extraModules`
via `mkDefault`. Override any value in your NixOS config to take precedence.

## Distribution System

K3s and vanilla K8s components are built per-track (1.30 through 1.35).
The overlay exposes packages like:

```
blackmatter-k3s              # default track (1.34)
blackmatter-k3s-latest       # latest track (1.35)
blackmatter-k3s-1-32         # specific track
blackmatter-kubectl-1-33     # vanilla k8s component, specific track
```

The `distribution` option on the k3s module auto-selects the matching package.

## Testing

```bash
# Unit tests (fast, pure Nix evaluation)
nix eval .#tests.x86_64-linux.unit

# Integration tests (NixOS VM, requires x86_64-linux)
nix build .#checks.x86_64-linux.single-node
nix build .#checks.x86_64-linux.multi-node
nix build .#checks.x86_64-linux.ha-server
nix build .#checks.x86_64-linux.single-node-flannel-minimal
nix build .#checks.x86_64-linux.k8s-single-node

# Latest track variants
nix build .#checks.x86_64-linux.single-node-latest
nix build .#checks.x86_64-linux.multi-node-latest
```

## Key Constraints

- NixOS modules are **Linux-only**. The home-manager module is cross-platform.
- Profile values use `mkDefault` -- user config always wins.
- The `nix` repo (private) wires user-specific config (IPs, tokens, secrets).
  This repo stays generic and public.
- Shell logic in the module is minimal (DNS check script, NVIDIA post-start).
  Prefer Rust tooling (kindling, kikai) for orchestration.
