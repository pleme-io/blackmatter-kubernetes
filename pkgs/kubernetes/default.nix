# Vanilla Kubernetes packages — control plane + runtime components
#
# Builds all Kubernetes binaries from the upstream monorepo and runtime
# components from their respective upstream repos.
#
# Tracks: 1.30 (eol), 1.31 (eol), 1.32 (eol), 1.33, 1.34 (default), 1.35 (latest)
#
# Usage:
#   k8s = import ./pkgs/kubernetes { inherit pkgs mkGoMonorepoSource mkGoMonorepoBinary; };
#   k8s.kubelet_1_34    # kubelet from k8s 1.34 track
#   k8s.kubeadm_1_35    # kubeadm from k8s 1.35 track
{ pkgs, mkGoMonorepoSource, mkGoMonorepoBinary }:

let
  lib = pkgs.lib;
  versionRegistry = import ../../lib/versions;
  mkSource = import ./source.nix { inherit mkGoMonorepoSource pkgs; };
  mkRuntimeComponent = import ./mk-runtime-component.nix { inherit pkgs; };

  allTracks = [ "1.30" "1.31" "1.32" "1.33" "1.34" "1.35" ];

  # Build all components for a given track
  mkTrack = track: let
    versions = versionRegistry.${track};
    hashes = import ./versions/${builtins.replaceStrings ["."] ["_"] track}.nix;
    k8sSrc = mkSource { inherit versions hashes; };
  in {
    kubectl = import ./kubectl.nix { inherit pkgs k8sSrc mkGoMonorepoBinary; };
    kubelet = import ./kubelet.nix { inherit pkgs k8sSrc mkGoMonorepoBinary; };
    kubeadm = import ./kubeadm.nix { inherit pkgs k8sSrc mkGoMonorepoBinary; };
    kube-apiserver = import ./kube-apiserver.nix { inherit pkgs k8sSrc mkGoMonorepoBinary; };
    kube-controller-manager = import ./kube-controller-manager.nix { inherit pkgs k8sSrc mkGoMonorepoBinary; };
    kube-scheduler = import ./kube-scheduler.nix { inherit pkgs k8sSrc mkGoMonorepoBinary; };
    kube-proxy = import ./kube-proxy.nix { inherit pkgs k8sSrc mkGoMonorepoBinary; };
    etcd = import ./etcd.nix { inherit mkRuntimeComponent; inherit (versions) etcdVersion; };
    containerd = import ./containerd.nix { inherit mkRuntimeComponent pkgs; inherit (versions) containerdVersion; };
    runc = import ./runc.nix { inherit mkRuntimeComponent pkgs; inherit (versions) runcVersion; };
    cni-plugins = import ./cni-plugins.nix { inherit mkRuntimeComponent; inherit (versions) cniPluginsVersion; };
    crictl = import ./crictl.nix { inherit mkRuntimeComponent; inherit (versions) crictlVersion; };
  };

  # Build all tracks
  tracks = lib.genAttrs allTracks mkTrack;

  # Generate flat exports: <component>_<track> for each track
  componentNames = [ "kubectl" "kubelet" "kubeadm" "kube-apiserver" "kube-controller-manager"
                     "kube-scheduler" "kube-proxy" "etcd" "containerd" "runc"
                     "cni-plugins" "crictl" ];

  flatExports = lib.listToAttrs (lib.concatMap (track:
    let
      trackSuffix = builtins.replaceStrings ["."] ["_"] track;
      trackPkgs = tracks.${track};
    in map (comp: {
      name = "${comp}_${trackSuffix}";
      value = trackPkgs.${comp};
    }) componentNames
  ) allTracks);

  # Track attrsets keyed as track_1_XX for module consumption
  trackAttrs = lib.listToAttrs (map (track: {
    name = "track_${builtins.replaceStrings ["."] ["_"] track}";
    value = tracks.${track};
  }) allTracks);

in flatExports // trackAttrs
