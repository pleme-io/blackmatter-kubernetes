# Vanilla Kubernetes packages — control plane + runtime components
#
# Builds all Kubernetes binaries from the upstream monorepo and runtime
# components from their respective upstream repos.
#
# Usage:
#   k8s = import ./pkgs/kubernetes { inherit pkgs mkGoMonorepoSource; };
#   k8s.kubelet_1_34    # kubelet from k8s 1.34 track
#   k8s.kubeadm_1_35    # kubeadm from k8s 1.35 track
{ pkgs, mkGoMonorepoSource }:

let
  lib = pkgs.lib;
  versionRegistry = import ../../lib/versions;
  mkSource = import ./source.nix { inherit mkGoMonorepoSource pkgs; };

  # Build all components for a given track
  mkTrack = track: let
    versions = versionRegistry.${track};
    hashes = import ./versions/${builtins.replaceStrings ["."] ["_"] track}.nix;
    k8sSrc = mkSource { inherit versions hashes; };
  in {
    kubelet = import ./kubelet.nix { inherit pkgs k8sSrc; };
    kubeadm = import ./kubeadm.nix { inherit pkgs k8sSrc; };
    kube-apiserver = import ./kube-apiserver.nix { inherit pkgs k8sSrc; };
    kube-controller-manager = import ./kube-controller-manager.nix { inherit pkgs k8sSrc; };
    kube-scheduler = import ./kube-scheduler.nix { inherit pkgs k8sSrc; };
    kube-proxy = import ./kube-proxy.nix { inherit pkgs k8sSrc; };
    etcd = import ./etcd.nix { inherit pkgs; inherit (versions) etcdVersion; };
    containerd = import ./containerd.nix { inherit pkgs; inherit (versions) containerdVersion; };
    runc = import ./runc.nix { inherit pkgs; inherit (versions) runcVersion; };
    cni-plugins = import ./cni-plugins.nix { inherit pkgs; inherit (versions) cniPluginsVersion; };
    crictl = import ./crictl.nix { inherit pkgs; inherit (versions) crictlVersion; };
  };

  track_1_34 = mkTrack "1.34";
  track_1_35 = mkTrack "1.35";

in {
  # 1.34 track (default)
  kubelet_1_34 = track_1_34.kubelet;
  kubeadm_1_34 = track_1_34.kubeadm;
  kube-apiserver_1_34 = track_1_34.kube-apiserver;
  kube-controller-manager_1_34 = track_1_34.kube-controller-manager;
  kube-scheduler_1_34 = track_1_34.kube-scheduler;
  kube-proxy_1_34 = track_1_34.kube-proxy;
  etcd_1_34 = track_1_34.etcd;
  containerd_1_34 = track_1_34.containerd;
  runc_1_34 = track_1_34.runc;
  cni-plugins_1_34 = track_1_34.cni-plugins;
  crictl_1_34 = track_1_34.crictl;

  # 1.35 track (latest)
  kubelet_1_35 = track_1_35.kubelet;
  kubeadm_1_35 = track_1_35.kubeadm;
  kube-apiserver_1_35 = track_1_35.kube-apiserver;
  kube-controller-manager_1_35 = track_1_35.kube-controller-manager;
  kube-scheduler_1_35 = track_1_35.kube-scheduler;
  kube-proxy_1_35 = track_1_35.kube-proxy;
  etcd_1_35 = track_1_35.etcd;
  containerd_1_35 = track_1_35.containerd;
  runc_1_35 = track_1_35.runc;
  cni-plugins_1_35 = track_1_35.cni-plugins;
  crictl_1_35 = track_1_35.crictl;

  # Track attrsets for module consumption
  inherit track_1_34 track_1_35;
}
