# Single-node k3s integration test
#
# Verifies: k3s server starts, cluster is healthy, pod scheduling works.
# Runs in a NixOS VM (x86_64-linux only, ~1536MB RAM, ~4096MB disk).
#
# Accepts optional `profile` parameter to test with a cluster profile.
# When profile is set, its disable/extraFlags are used instead of the
# hardcoded test defaults.
{ pkgs, lib, k3sModule, k3sPackage, profile ? null }:

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

  testName =
    if profile != null
    then "k3s-single-node-${profile}"
    else "k3s-single-node";

  # Base k3s config — always set
  baseK3sConfig = {
    enable = true;
    package = k3sPackage;
    role = "server";
    extraFlags = [ "--pause-image test.local/pause:local" ];
  };

  # When no profile, use hardcoded minimal disable set for fast tests.
  # When profile is set, let the profile set disable/extraFlags via mkDefault.
  k3sConfig =
    if profile != null
    then baseK3sConfig // { inherit profile; }
    else baseK3sConfig // {
      disable = [ "coredns" "local-storage" "metrics-server" "servicelb" "traefik" ];
    };

in
pkgs.testers.runNixOSTest {
  name = testName;

  nodes.machine = { pkgs, ... }: {
    imports = [ k3sModule ];

    environment.systemPackages = with pkgs; [
      k3sPackage
      gzip
    ];

    virtualisation.memorySize = 1536;
    virtualisation.diskSize = 4096;

    services.blackmatter.k3s = k3sConfig;
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
