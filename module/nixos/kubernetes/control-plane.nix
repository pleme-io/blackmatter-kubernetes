# Kubernetes control plane — apiserver, controller-manager, scheduler
#
# Runs the three core control plane components as separate systemd services.
# Only active when role == "control-plane".
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.blackmatter.kubernetes;
  cpCfg = cfg.controlPlane;

  # API server flags
  apiServerFlags = [
    "--advertise-address=${cfg.nodeIP or "0.0.0.0"}"
    "--allow-privileged=true"
    "--authorization-mode=Node,RBAC"
    "--client-ca-file=${cfg.pki.certificateDir}/ca.crt"
    "--enable-admission-plugins=NodeRestriction"
    "--etcd-cafile=${cfg.pki.certificateDir}/etcd/ca.crt"
    "--etcd-certfile=${cfg.pki.certificateDir}/apiserver-etcd-client.crt"
    "--etcd-keyfile=${cfg.pki.certificateDir}/apiserver-etcd-client.key"
    "--kubelet-client-certificate=${cfg.pki.certificateDir}/apiserver-kubelet-client.crt"
    "--kubelet-client-key=${cfg.pki.certificateDir}/apiserver-kubelet-client.key"
    "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname"
    "--proxy-client-cert-file=${cfg.pki.certificateDir}/front-proxy-client.crt"
    "--proxy-client-key-file=${cfg.pki.certificateDir}/front-proxy-client.key"
    "--requestheader-allowed-names=front-proxy-client"
    "--requestheader-client-ca-file=${cfg.pki.certificateDir}/front-proxy-ca.crt"
    "--requestheader-extra-headers-prefix=X-Remote-Extra-"
    "--requestheader-group-headers=X-Remote-Group"
    "--requestheader-username-headers=X-Remote-User"
    "--secure-port=${toString cfg.firewall.apiServerPort}"
    "--service-account-issuer=https://kubernetes.default.svc.cluster.local"
    "--service-account-key-file=${cfg.pki.certificateDir}/sa.pub"
    "--service-account-signing-key-file=${cfg.pki.certificateDir}/sa.key"
    "--service-cluster-ip-range=${cfg.serviceCIDR}"
    "--tls-cert-file=${cfg.pki.certificateDir}/apiserver.crt"
    "--tls-private-key-file=${cfg.pki.certificateDir}/apiserver.key"
  ]
  ++ optional (cpCfg.etcd.external) "--etcd-servers=${concatStringsSep "," cpCfg.etcd.endpoints}"
  ++ optional (!cpCfg.etcd.external) "--etcd-servers=http://127.0.0.1:2379"
  ++ map (san: "--apiserver-extra-sans=${san}") cpCfg.apiServerExtraSANs
  ++ mapAttrsToList (k: v: "--${k}=${toString v}") cpCfg.apiServerExtraArgs;

  # Controller manager flags
  controllerManagerFlags = [
    "--allocate-node-cidrs=true"
    "--authentication-kubeconfig=/etc/kubernetes/controller-manager.conf"
    "--authorization-kubeconfig=/etc/kubernetes/controller-manager.conf"
    "--bind-address=127.0.0.1"
    "--client-ca-file=${cfg.pki.certificateDir}/ca.crt"
    "--cluster-cidr=${cfg.clusterCIDR}"
    "--cluster-signing-cert-file=${cfg.pki.certificateDir}/ca.crt"
    "--cluster-signing-key-file=${cfg.pki.certificateDir}/ca.key"
    "--controllers=*,bootstrapsigner,tokencleaner"
    "--kubeconfig=/etc/kubernetes/controller-manager.conf"
    "--leader-elect=true"
    "--requestheader-client-ca-file=${cfg.pki.certificateDir}/front-proxy-ca.crt"
    "--root-ca-file=${cfg.pki.certificateDir}/ca.crt"
    "--service-account-private-key-file=${cfg.pki.certificateDir}/sa.key"
    "--service-cluster-ip-range=${cfg.serviceCIDR}"
    "--use-service-account-credentials=true"
  ]
  ++ mapAttrsToList (k: v: "--${k}=${toString v}") cpCfg.controllerManagerExtraArgs;

  # Scheduler flags
  schedulerFlags = [
    "--authentication-kubeconfig=/etc/kubernetes/scheduler.conf"
    "--authorization-kubeconfig=/etc/kubernetes/scheduler.conf"
    "--bind-address=127.0.0.1"
    "--kubeconfig=/etc/kubernetes/scheduler.conf"
    "--leader-elect=true"
  ]
  ++ mapAttrsToList (k: v: "--${k}=${toString v}") cpCfg.schedulerExtraArgs;

in {
  options.services.blackmatter.kubernetes.controlPlane = {
    apiServerExtraArgs = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Extra arguments for kube-apiserver";
    };

    controllerManagerExtraArgs = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Extra arguments for kube-controller-manager";
    };

    schedulerExtraArgs = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Extra arguments for kube-scheduler";
    };

    apiServerExtraSANs = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Extra Subject Alternative Names for the API server certificate";
      example = [ "kubernetes.example.com" "10.0.0.100" ];
    };

    disableKubeProxy = mkOption {
      type = types.bool;
      default = false;
      description = "Disable kube-proxy (e.g., when using Cilium in kube-proxy replacement mode)";
    };

    kubeProxyExtraArgs = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Extra arguments for kube-proxy";
    };

    etcd = {
      external = mkOption {
        type = types.bool;
        default = false;
        description = "Use external etcd cluster (instead of stacked/local)";
      };

      endpoints = mkOption {
        type = types.listOf types.str;
        default = [ "http://127.0.0.1:2379" ];
        description = "etcd endpoints (for external etcd)";
      };

      caFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to etcd CA certificate (for external etcd)";
      };

      certFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to etcd client certificate (for external etcd)";
      };

      keyFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to etcd client key (for external etcd)";
      };
    };
  };

  config = mkIf (cfg.enable && cfg.role == "control-plane") {
    # ── kube-apiserver ──────────────────────────────────────────────────
    systemd.services.kube-apiserver = {
      description = "Kubernetes API Server";
      after = [ "network-online.target" ]
              ++ optional cfg.etcd.enable "etcd.service";
      wants = [ "network-online.target" ]
              ++ optional cfg.etcd.enable "etcd.service";
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "notify";
        ExecStart = "${cfg.packages.kube-apiserver}/bin/kube-apiserver ${concatStringsSep " \\\n  " apiServerFlags}";
        Restart = "on-failure";
        RestartSec = 5;
        LimitNOFILE = 65536;
      };
    };

    # ── kube-controller-manager ─────────────────────────────────────────
    systemd.services.kube-controller-manager = {
      description = "Kubernetes Controller Manager";
      after = [ "kube-apiserver.service" ];
      wants = [ "kube-apiserver.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.packages.kube-controller-manager}/bin/kube-controller-manager ${concatStringsSep " \\\n  " controllerManagerFlags}";
        Restart = "on-failure";
        RestartSec = 5;
        LimitNOFILE = 65536;
      };
    };

    # ── kube-scheduler ──────────────────────────────────────────────────
    systemd.services.kube-scheduler = {
      description = "Kubernetes Scheduler";
      after = [ "kube-apiserver.service" ];
      wants = [ "kube-apiserver.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.packages.kube-scheduler}/bin/kube-scheduler ${concatStringsSep " \\\n  " schedulerFlags}";
        Restart = "on-failure";
        RestartSec = 5;
        LimitNOFILE = 65536;
      };
    };

    # ── Stacked etcd (auto-enable when not using external) ──────────────
    services.blackmatter.kubernetes.etcd.enable = mkDefault (!cpCfg.etcd.external);
  };
}
