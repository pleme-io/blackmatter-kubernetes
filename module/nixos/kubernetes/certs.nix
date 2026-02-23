# Kubernetes PKI — certificate management for vanilla k8s
#
# Manages the cluster's PKI infrastructure. Supports three modes:
# 1. kubeadm-managed (default) — kubeadm generates all certs on init
# 2. External CA — user provides pre-generated cert/key paths
# 3. SOPS-managed — certs decrypted from SOPS secrets at activation
#
# Certificate hierarchy:
#   CA → apiserver, kubelet-client, front-proxy, etcd (peer + client)
#   SA key pair → service account tokens
{ config, lib, ... }:

with lib;

let
  cfg = config.services.blackmatter.kubernetes;
  certsCfg = cfg.pki;
  certDir = "${cfg.dataDir}/pki";
in {
  options.services.blackmatter.kubernetes.pki = {
    mode = mkOption {
      type = types.enum [ "kubeadm" "external" ];
      default = "kubeadm";
      description = ''
        PKI management mode:
        - kubeadm: kubeadm generates and manages all certificates
        - external: user provides paths to pre-generated certificates
      '';
    };

    certificateDir = mkOption {
      type = types.str;
      default = certDir;
      description = "Directory for Kubernetes PKI files";
    };

    external = {
      caCert = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to external CA certificate";
      };

      caKey = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to external CA key";
      };

      apiServerCert = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to API server certificate";
      };

      apiServerKey = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to API server key";
      };

      frontProxyCACert = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to front-proxy CA certificate";
      };

      frontProxyCAKey = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to front-proxy CA key";
      };

      etcdCACert = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to etcd CA certificate";
      };

      etcdCAKey = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to etcd CA key";
      };

      saKey = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to service account signing key";
      };

      saPub = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to service account public key";
      };
    };
  };

  config = mkIf (cfg.enable && certsCfg.mode == "external") {
    assertions = [
      {
        assertion = certsCfg.external.caCert != null && certsCfg.external.caKey != null;
        message = "services.blackmatter.kubernetes.pki: external mode requires caCert and caKey";
      }
    ];

    # Copy external certs to the expected PKI directory
    system.activationScripts.kubernetes-pki = {
      text = ''
        mkdir -p ${certsCfg.certificateDir}
        ${optionalString (certsCfg.external.caCert != null) ''
          cp -f ${certsCfg.external.caCert} ${certsCfg.certificateDir}/ca.crt
          cp -f ${certsCfg.external.caKey} ${certsCfg.certificateDir}/ca.key
          chmod 600 ${certsCfg.certificateDir}/ca.key
        ''}
        ${optionalString (certsCfg.external.frontProxyCACert != null) ''
          cp -f ${certsCfg.external.frontProxyCACert} ${certsCfg.certificateDir}/front-proxy-ca.crt
          cp -f ${certsCfg.external.frontProxyCAKey} ${certsCfg.certificateDir}/front-proxy-ca.key
          chmod 600 ${certsCfg.certificateDir}/front-proxy-ca.key
        ''}
        ${optionalString (certsCfg.external.etcdCACert != null) ''
          mkdir -p ${certsCfg.certificateDir}/etcd
          cp -f ${certsCfg.external.etcdCACert} ${certsCfg.certificateDir}/etcd/ca.crt
          cp -f ${certsCfg.external.etcdCAKey} ${certsCfg.certificateDir}/etcd/ca.key
          chmod 600 ${certsCfg.certificateDir}/etcd/ca.key
        ''}
        ${optionalString (certsCfg.external.saKey != null) ''
          cp -f ${certsCfg.external.saKey} ${certsCfg.certificateDir}/sa.key
          cp -f ${certsCfg.external.saPub} ${certsCfg.certificateDir}/sa.pub
          chmod 600 ${certsCfg.certificateDir}/sa.key
        ''}
      '';
      deps = [];
    };
  };
}
