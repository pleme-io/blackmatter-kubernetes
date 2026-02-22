# HA control plane integration test
#
# Verifies: 3-server HA cluster with embedded etcd, survives node failure.
# Runs in NixOS VMs (x86_64-linux only).
{ pkgs, lib, k3sModule, k3sPackage }:

let
  tokenFile = pkgs.writeText "token" "ha-cluster-token";
in
pkgs.testers.runNixOSTest {
  name = "k3s-ha-server";

  nodes = {
    server1 = { nodes, pkgs, ... }: {
      imports = [ k3sModule ];

      environment.systemPackages = with pkgs; [ jq ];
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
          "--node-ip ${nodes.server1.networking.primaryIPAddress}"
          "--flannel-iface eth1"
        ];
        firewall.extraTCPPorts = [ 2379 2380 ];
      };
    };

    server2 = { nodes, pkgs, ... }: {
      imports = [ k3sModule ];

      environment.systemPackages = with pkgs; [ jq ];
      virtualisation.memorySize = 1536;
      virtualisation.diskSize = 4096;

      services.blackmatter.k3s = {
        enable = true;
        package = k3sPackage;
        role = "server";
        serverAddr = "https://${nodes.server1.networking.primaryIPAddress}:6443";
        tokenFile = tokenFile;
        disable = [ "coredns" "local-storage" "metrics-server" "servicelb" "traefik" ];
        extraFlags = [
          "--node-ip ${nodes.server2.networking.primaryIPAddress}"
          "--flannel-iface eth1"
        ];
        firewall.extraTCPPorts = [ 2379 2380 ];
      };
    };

    server3 = { nodes, pkgs, ... }: {
      imports = [ k3sModule ];

      environment.systemPackages = with pkgs; [ jq ];
      virtualisation.memorySize = 1536;
      virtualisation.diskSize = 4096;

      services.blackmatter.k3s = {
        enable = true;
        package = k3sPackage;
        role = "server";
        serverAddr = "https://${nodes.server1.networking.primaryIPAddress}:6443";
        tokenFile = tokenFile;
        disable = [ "coredns" "local-storage" "metrics-server" "servicelb" "traefik" ];
        extraFlags = [
          "--node-ip ${nodes.server3.networking.primaryIPAddress}"
          "--flannel-iface eth1"
        ];
        firewall.extraTCPPorts = [ 2379 2380 ];
      };
    };
  };

  testScript = ''
    start_all()

    # Wait for all servers
    for m in [server1, server2, server3]:
        m.wait_for_unit("k3s")

    # All nodes should be Ready
    server1.wait_until_succeeds("k3s kubectl get node server2")
    server1.wait_until_succeeds("k3s kubectl get node server3")
    server1.succeed("k3s kubectl cluster-info")

    # Verify all 3 nodes are Ready
    server1.wait_until_succeeds(
        '[ "$(k3s kubectl get nodes --no-headers | grep -c Ready)" -eq 3 ]'
    )

    # Kill server2 — cluster should remain functional via server1 + server3
    server2.crash()

    # Verify cluster still works (etcd quorum: 2/3)
    server1.succeed("k3s kubectl get nodes")
    server1.succeed("k3s kubectl create configmap ha-test --from-literal=key=value")
    server3.succeed("k3s kubectl get configmap ha-test")
    server1.succeed("k3s kubectl delete configmap ha-test")
  '';
}
