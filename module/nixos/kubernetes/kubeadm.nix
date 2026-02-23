# Kubernetes kubeadm — cluster bootstrap integration
#
# Generates kubeadm configuration from NixOS options and provides
# activation scripts for `kubeadm init` (first control plane) and
# `kubeadm join` (additional control planes and workers).
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.blackmatter.kubernetes;

  # Generate kubeadm ClusterConfiguration YAML from NixOS options
  kubeadmConfig = pkgs.writeText "kubeadm-config.yaml" ''
    apiVersion: kubeadm.k8s.io/v1beta4
    kind: ClusterConfiguration
    kubernetesVersion: v${cfg.versions.kubernetesVersion}
    controlPlaneEndpoint: "${cfg.serverAddr}"
    networking:
      podSubnet: "${cfg.clusterCIDR}"
      serviceSubnet: "${cfg.serviceCIDR}"
      dnsDomain: "cluster.local"
    ${optionalString (cfg.controlPlane.apiServerExtraSANs != []) ''
    apiServer:
      certSANs:
    ${concatMapStrings (san: "    - ${san}\n") cfg.controlPlane.apiServerExtraSANs}''}
    ${optionalString (cfg.controlPlane.etcd.external) ''
    etcd:
      external:
        endpoints:
    ${concatMapStrings (ep: "      - ${ep}\n") cfg.controlPlane.etcd.endpoints}
    ${optionalString (cfg.controlPlane.etcd.caFile != null) "    caFile: ${cfg.controlPlane.etcd.caFile}"}
    ${optionalString (cfg.controlPlane.etcd.certFile != null) "    certFile: ${cfg.controlPlane.etcd.certFile}"}
    ${optionalString (cfg.controlPlane.etcd.keyFile != null) "    keyFile: ${cfg.controlPlane.etcd.keyFile}"}
    ''}
    ---
    apiVersion: kubeadm.k8s.io/v1beta4
    kind: InitConfiguration
    ${optionalString (cfg.nodeName != null) "nodeRegistration:\n  name: ${cfg.nodeName}"}
    ${optionalString (cfg.nodeIP != null) ''
    localAPIEndpoint:
      advertiseAddress: ${cfg.nodeIP}
    ''}
  '';

  # Generate kubeadm JoinConfiguration YAML
  kubeadmJoinConfig = pkgs.writeText "kubeadm-join-config.yaml" ''
    apiVersion: kubeadm.k8s.io/v1beta4
    kind: JoinConfiguration
    discovery:
      bootstrapToken:
        apiServerEndpoint: "${cfg.serverAddr}"
        token: "PLACEHOLDER"
        unsafeSkipCAVerification: true
    ${optionalString (cfg.nodeName != null) "nodeRegistration:\n  name: ${cfg.nodeName}"}
    ${optionalString (cfg.role == "control-plane") ''
    controlPlane:
      localAPIEndpoint:
        advertiseAddress: ${cfg.nodeIP or "0.0.0.0"}
    ''}
  '';

in {
  config = mkIf cfg.enable {
    # Make kubeadm config available at a well-known path
    environment.etc."kubernetes/kubeadm-config.yaml" = mkIf (cfg.role == "control-plane") {
      source = kubeadmConfig;
    };

    environment.etc."kubernetes/kubeadm-join-config.yaml" = mkIf (cfg.serverAddr != "") {
      source = kubeadmJoinConfig;
    };

    # Provide kubeadm + kubectl in system packages for manual operations
    environment.systemPackages = [
      cfg.packages.kubeadm
      cfg.packages.kubelet
      cfg.packages.crictl
    ];
  };
}
