# Kubernetes kubelet — node agent + container runtime management
#
# Runs on every node (control plane and worker). Manages the container
# runtime (containerd) and reports node/pod status to the API server.
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.blackmatter.kubernetes;

  kubeletFlags = [
    "--kubeconfig=/etc/kubernetes/kubelet.conf"
    "--config=/var/lib/kubelet/config.yaml"
    "--container-runtime-endpoint=unix:///run/containerd/containerd.sock"
  ]
  ++ optional (cfg.nodeName != null) "--hostname-override=${cfg.nodeName}"
  ++ optional (cfg.nodeIP != null) "--node-ip=${cfg.nodeIP}"
  ++ cfg.extraFlags;

  # Containerd config
  containerdConfig = pkgs.writeText "containerd-config.toml" (
    if cfg.containerRuntime.containerdConfigTemplate != null
    then cfg.containerRuntime.containerdConfigTemplate
    else ''
      version = 3

      [plugins."io.containerd.grpc.v1.cri"]
        sandbox_image = "registry.k8s.io/pause:${cfg.versions.pauseVersion}"

      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
        runtime_type = "io.containerd.runc.v2"

      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
        SystemdCgroup = true
    ''
  );

  containerdFlags = [
    "--config ${containerdConfig}"
  ];

  kubeProxyFlags = [
    "--kubeconfig=/etc/kubernetes/kube-proxy.conf"
    "--cluster-cidr=${cfg.clusterCIDR}"
  ]
  ++ mapAttrsToList (k: v: "--${k}=${toString v}") cfg.controlPlane.kubeProxyExtraArgs;

in {
  config = mkIf cfg.enable (mkMerge [
    # ── containerd service ──────────────────────────────────────────────
    {
      systemd.services.containerd = {
        description = "containerd container runtime";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "notify";
          ExecStart = "${cfg.packages.containerd}/bin/containerd ${concatStringsSep " " containerdFlags}";
          Delegate = "yes";
          KillMode = "process";
          Restart = "always";
          RestartSec = 5;
          LimitNOFILE = 1048576;
          LimitNPROC = "infinity";
          LimitCORE = "infinity";
        };
      };
    }

    # ── kubelet service ─────────────────────────────────────────────────
    {
      systemd.services.kubelet = {
        description = "Kubernetes Kubelet";
        after = [ "network-online.target" "containerd.service" ];
        wants = [ "network-online.target" "containerd.service" ];
        wantedBy = [ "multi-user.target" ];

        path = with cfg.packages; [
          kubelet
          runc
          crictl
          cni-plugins
          pkgs.iptables
          pkgs.iproute2
          pkgs.conntrack-tools
          pkgs.socat
          pkgs.util-linuxMinimal
        ];

        serviceConfig = {
          Type = "notify";
          ExecStart = "${cfg.packages.kubelet}/bin/kubelet ${concatStringsSep " " kubeletFlags}";
          Restart = "always";
          RestartSec = 5;
          KillMode = "process";
          Delegate = "yes";
          LimitNOFILE = 1048576;
          LimitNPROC = "infinity";
          LimitCORE = "infinity";
        }
        // optionalAttrs (cfg.environmentFile != null) {
          EnvironmentFile = cfg.environmentFile;
        };
      };
    }

    # ── kube-proxy service (unless disabled by profile) ─────────────────
    (mkIf (!cfg.controlPlane.disableKubeProxy) {
      systemd.services.kube-proxy = {
        description = "Kubernetes Network Proxy";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "simple";
          ExecStart = "${cfg.packages.kube-proxy}/bin/kube-proxy ${concatStringsSep " " kubeProxyFlags}";
          Restart = "on-failure";
          RestartSec = 5;
          LimitNOFILE = 65536;
        };
      };
    })

    # ── CNI directories ─────────────────────────────────────────────────
    {
      environment.etc."cni/net.d/.keep".text = "";
      systemd.tmpfiles.rules = [
        "d /opt/cni/bin 0755 root root -"
        "d /etc/cni/net.d 0755 root root -"
        "d /var/lib/kubelet 0755 root root -"
        "d /etc/kubernetes 0755 root root -"
        "d /etc/kubernetes/manifests 0755 root root -"
      ];

      # Symlink CNI plugins into standard path
      system.activationScripts.cni-plugins = {
        text = ''
          for plugin in ${cfg.packages.cni-plugins}/bin/*; do
            ln -sf "$plugin" /opt/cni/bin/
          done
        '';
        deps = [];
      };
    }
  ]);
}
