# kubelet — Kubernetes node agent
#
# Runs on every node. Manages pods and containers via the container runtime.
# Requires systemd and conntrack-tools at runtime.
{ pkgs, k8sSrc }:

pkgs.buildGoModule {
  pname = "kubelet";
  inherit (k8sSrc) version src;

  vendorHash = null;
  subPackages = [ "cmd/kubelet" ];
  ldflags = k8sSrc.ldflags;
  doCheck = false;

  meta = {
    description = "Kubernetes node agent";
    homepage = "https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/";
    license = pkgs.lib.licenses.asl20;
    mainProgram = "kubelet";
    platforms = pkgs.lib.platforms.linux;
  };
}
