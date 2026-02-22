# K8s Network Plugins & Service Meshes — built from source with our Go toolchain
#
# CNI plugins, network daemons, and service mesh CLIs.
# All Linux-only except istioctl and linkerd CLI.
{ mkGoTool, pkgs }:

{
  # ── CNI Plugins ────────────────────────────────────────────────────
  cni-plugins = import ./cni-plugins.nix { inherit pkgs; };
  flannel = import ./flannel.nix { inherit mkGoTool pkgs; };
  cni-plugin-flannel = import ./cni-plugin-flannel.nix { inherit mkGoTool pkgs; };
  multus-cni = import ./multus-cni.nix { inherit mkGoTool pkgs; };

  # ── Calico (CNI + daemon components) ───────────────────────────────
  calico-cni-plugin = import ./calico.nix { inherit mkGoTool pkgs; component = "calico-cni-plugin"; };
  calico-apiserver = import ./calico.nix { inherit mkGoTool pkgs; component = "calico-apiserver"; };
  calico-typha = import ./calico.nix { inherit mkGoTool pkgs; component = "calico-typha"; };
  calico-kube-controllers = import ./calico.nix { inherit mkGoTool pkgs; component = "calico-kube-controllers"; };
  calico-pod2daemon = import ./calico.nix { inherit mkGoTool pkgs; component = "calico-pod2daemon"; };
  confd-calico = import ./calico.nix { inherit mkGoTool pkgs; component = "confd-calico"; };

  # ── Service Mesh CLIs ──────────────────────────────────────────────
  istioctl = import ./istioctl.nix { inherit mkGoTool pkgs; };
  linkerd = import ./linkerd.nix { inherit mkGoTool pkgs; };

  # ── Network Observability & Certificate Management ────────────────
  hubble = import ./hubble.nix { inherit mkGoTool pkgs; };
  cmctl = import ./cmctl.nix { inherit mkGoTool pkgs; };
}
