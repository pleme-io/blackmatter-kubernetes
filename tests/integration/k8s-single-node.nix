# Single-node vanilla Kubernetes integration test
#
# Verifies: kubeadm init, kubelet starts, cluster is healthy.
# Runs in a NixOS VM (x86_64-linux only).
#
# This is a basic smoke test — kubeadm init → kubectl get nodes → Ready.
{ pkgs, lib, k8sModule, profile ? null }:

let
  testName =
    if profile != null
    then "k8s-single-node-${profile}"
    else "k8s-single-node";

  k8sConfig = {
    enable = true;
    role = "control-plane";
    distribution = "1.34";
    nodeIP = "192.168.1.1";
    nodeName = "test-node";
    clusterCIDR = "10.42.0.0/16";
    serviceCIDR = "10.43.0.0/16";
    clusterDNS = "10.43.0.10";
    pki.mode = "kubeadm";
  } // lib.optionalAttrs (profile != null) { inherit profile; };

in
pkgs.testers.runNixOSTest {
  name = testName;

  nodes.machine = { pkgs, ... }: {
    imports = [ k8sModule ];

    virtualisation.memorySize = 2048;
    virtualisation.diskSize = 8192;

    services.blackmatter.kubernetes = k8sConfig;

    # kubeadm init needs network
    networking.interfaces.eth0.ipv4.addresses = [{
      address = "192.168.1.1";
      prefixLength = 24;
    }];
  };

  testScript = ''
    start_all()

    # Wait for containerd to start
    machine.wait_for_unit("containerd")

    # Run kubeadm init
    machine.succeed(
        "kubeadm init "
        "--pod-network-cidr=10.42.0.0/16 "
        "--service-cidr=10.43.0.0/16 "
        "--apiserver-advertise-address=192.168.1.1 "
        "--skip-phases=addon/kube-proxy "
        "2>&1"
    )

    # Wait for kubelet to be running
    machine.wait_for_unit("kubelet")

    # Set up kubeconfig
    machine.succeed("mkdir -p /root/.kube")
    machine.succeed("cp /etc/kubernetes/admin.conf /root/.kube/config")

    # Wait for node to be ready
    machine.wait_until_succeeds("kubectl get nodes | grep -q Ready", timeout=120)

    machine.shutdown()
  '';
}
