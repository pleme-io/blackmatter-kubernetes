# Multi-node k3s integration test
#
# Verifies: server + agent join, cross-node pod networking via socat echo.
# Runs in NixOS VMs (x86_64-linux only).
{ pkgs, lib, k3sModule, k3sPackage }:

let
  imageEnv = pkgs.buildEnv {
    name = "k3s-pause-image-env";
    paths = with pkgs; [
      tini
      bashInteractive
      coreutils
      socat
    ];
  };
  pauseImage = pkgs.dockerTools.buildImage {
    name = "test.local/pause";
    tag = "local";
    copyToRoot = imageEnv;
    config.Entrypoint = [
      "/bin/tini"
      "--"
      "/bin/sleep"
      "inf"
    ];
  };
  networkTestDaemonset = pkgs.writeText "test.yml" ''
    apiVersion: apps/v1
    kind: DaemonSet
    metadata:
      name: test
      labels:
        name: test
    spec:
      selector:
        matchLabels:
          name: test
      template:
        metadata:
          labels:
            name: test
        spec:
          containers:
          - name: test
            image: test.local/pause:local
            imagePullPolicy: Never
            resources:
              limits:
                memory: 20Mi
            command: ["socat", "TCP4-LISTEN:8000,fork", "EXEC:echo server"]
  '';
  tokenFile = pkgs.writeText "token" "test-cluster-token";
in
pkgs.testers.runNixOSTest {
  name = "k3s-multi-node";

  nodes = {
    server = { nodes, pkgs, ... }: {
      imports = [ k3sModule ];

      environment.systemPackages = with pkgs; [ gzip jq ];
      virtualisation.memorySize = 1536;
      virtualisation.diskSize = 4096;

      services.blackmatter.k3s = {
        enable = true;
        package = k3sPackage;
        role = "server";
        clusterInit = true;
        tokenFile = tokenFile;
        disable = [ "coredns" "local-storage" "metrics-server" "servicelb" "traefik" ];
        extraFlags = [
          "--pause-image test.local/pause:local"
          "--node-ip ${nodes.server.networking.primaryIPAddress}"
          "--flannel-iface eth1"
        ];
        images = [ pauseImage ];
        firewall.extraTCPPorts = [ 2379 2380 ];
      };
    };

    agent = { nodes, pkgs, ... }: {
      imports = [ k3sModule ];

      virtualisation.memorySize = 1024;
      virtualisation.diskSize = 2048;

      services.blackmatter.k3s = {
        enable = true;
        package = k3sPackage;
        role = "agent";
        serverAddr = "https://${nodes.server.networking.primaryIPAddress}:6443";
        tokenFile = tokenFile;
        extraFlags = [
          "--pause-image test.local/pause:local"
          "--node-ip ${nodes.agent.networking.primaryIPAddress}"
          "--flannel-iface eth1"
        ];
        images = [ pauseImage ];
      };
    };
  };

  testScript = ''
    start_all()

    server.wait_for_unit("k3s")
    agent.wait_for_unit("k3s")

    # Wait for agent to join
    server.wait_until_succeeds("k3s kubectl get node agent")
    server.succeed("k3s kubectl cluster-info")
    server.wait_until_succeeds("k3s kubectl get serviceaccount default")

    # Deploy DaemonSet and wait for pods on both nodes
    server.succeed("k3s kubectl apply -f ${networkTestDaemonset}")
    server.wait_until_succeeds('[ "$(k3s kubectl get ds test -o json | jq .status.numberReady)" -eq 2 ]')

    # Cross-node networking via socat
    pods = server.succeed("k3s kubectl get po -o json | jq '.items[].metadata.name' -r").splitlines()
    pod_ips = [server.succeed(f"k3s kubectl get po {name} -o json | jq '.status.podIP' -cr").strip() for name in pods]

    for pod_ip in pod_ips:
        server.succeed(f"ping -c 1 {pod_ip}")
        agent.succeed(f"ping -c 1 {pod_ip}")
        for pod in pods:
            resp = server.succeed(f"k3s kubectl exec {pod} -- socat TCP:{pod_ip}:8000 -")
            assert resp.strip() == "server"
  '';
}
