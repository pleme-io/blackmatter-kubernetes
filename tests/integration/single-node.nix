# Single-node k3s integration test
#
# Verifies: k3s server starts, cluster is healthy, pod scheduling works.
# Runs in a NixOS VM (x86_64-linux only, ~1536MB RAM, ~4096MB disk).
{ pkgs, lib, k3sModule, k3sPackage }:

let
  imageEnv = pkgs.buildEnv {
    name = "k3s-pause-image-env";
    paths = with pkgs; [
      tini
      (hiPrio coreutils)
      busybox
    ];
  };
  pauseImage = pkgs.dockerTools.streamLayeredImage {
    name = "test.local/pause";
    tag = "local";
    contents = imageEnv;
    config.Entrypoint = [
      "/bin/tini"
      "--"
      "/bin/sleep"
      "inf"
    ];
  };
  testPodYaml = pkgs.writeText "test.yml" ''
    apiVersion: v1
    kind: Pod
    metadata:
      name: test
    spec:
      containers:
      - name: test
        image: test.local/pause:local
        imagePullPolicy: Never
        command: ["sh", "-c", "sleep inf"]
  '';
in
pkgs.testers.runNixOSTest {
  name = "k3s-single-node";

  nodes.machine = { pkgs, ... }: {
    imports = [ k3sModule ];

    environment.systemPackages = with pkgs; [
      k3sPackage
      gzip
    ];

    virtualisation.memorySize = 1536;
    virtualisation.diskSize = 4096;

    services.blackmatter.k3s = {
      enable = true;
      package = k3sPackage;
      role = "server";
      disable = [ "coredns" "local-storage" "metrics-server" "servicelb" "traefik" ];
      extraFlags = [ "--pause-image test.local/pause:local" ];
    };
  };

  testScript = ''
    start_all()

    machine.wait_for_unit("k3s")
    machine.succeed("kubectl cluster-info")
    machine.succeed(
        "${pauseImage} | ctr image import -"
    )

    # Wait for service account
    machine.wait_until_succeeds("kubectl get serviceaccount default")
    machine.succeed("kubectl apply -f ${testPodYaml}")
    machine.succeed("kubectl wait --for 'condition=Ready' pod/test")
    machine.succeed("kubectl delete -f ${testPodYaml}")

    machine.shutdown()
  '';
}
