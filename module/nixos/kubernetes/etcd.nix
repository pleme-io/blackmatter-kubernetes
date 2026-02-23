# Kubernetes etcd — stacked etcd for vanilla k8s control planes
#
# Runs etcd as a systemd service alongside the API server (stacked topology).
# For external etcd, disable this and configure controlPlane.etcd.external.
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.blackmatter.kubernetes;
  etcdCfg = cfg.etcd;

  etcdFlags = [
    "--name ${cfg.nodeName or "default"}"
    "--data-dir ${etcdCfg.dataDir}"
    "--listen-client-urls http://127.0.0.1:2379,http://${cfg.nodeIP or "127.0.0.1"}:2379"
    "--advertise-client-urls http://${cfg.nodeIP or "127.0.0.1"}:2379"
    "--listen-peer-urls http://${cfg.nodeIP or "127.0.0.1"}:2380"
    "--initial-advertise-peer-urls http://${cfg.nodeIP or "127.0.0.1"}:2380"
  ]
  ++ optional (etcdCfg.initialCluster != "") "--initial-cluster ${etcdCfg.initialCluster}"
  ++ optional (etcdCfg.initialClusterState != "") "--initial-cluster-state ${etcdCfg.initialClusterState}"
  ++ mapAttrsToList (k: v: "--${k} ${toString v}") etcdCfg.extraArgs;

in {
  options.services.blackmatter.kubernetes.etcd = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Run a local etcd instance (stacked topology)";
    };

    package = mkOption {
      type = types.package;
      default = cfg.packages.etcd;
      description = "etcd server package";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/etcd";
      description = "etcd data directory";
    };

    initialCluster = mkOption {
      type = types.str;
      default = "";
      description = "Initial etcd cluster configuration (e.g., node1=http://10.0.0.1:2380,node2=http://10.0.0.2:2380)";
      example = "cp1=http://10.0.0.1:2380,cp2=http://10.0.0.2:2380,cp3=http://10.0.0.3:2380";
    };

    initialClusterState = mkOption {
      type = types.enum [ "" "new" "existing" ];
      default = "";
      description = "Initial cluster state (new for bootstrap, existing for joining)";
    };

    extraArgs = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Extra etcd command-line arguments as key-value pairs";
    };
  };

  config = mkIf (cfg.enable && etcdCfg.enable) {
    systemd.services.etcd = {
      description = "etcd — distributed key-value store";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "notify";
        ExecStart = "${etcdCfg.package}/bin/etcd ${concatStringsSep " " etcdFlags}";
        Restart = "on-failure";
        RestartSec = 5;
        LimitNOFILE = 65536;
        StateDirectory = "etcd";
        User = "etcd";
        Group = "etcd";
      };
    };

    users.users.etcd = {
      isSystemUser = true;
      group = "etcd";
      home = etcdCfg.dataDir;
      createHome = true;
    };

    users.groups.etcd = {};

    # Firewall: etcd client (2379) + peer (2380)
    networking.firewall = mkIf cfg.firewall.enable {
      allowedTCPPorts = [ 2379 2380 ];
    };
  };
}
