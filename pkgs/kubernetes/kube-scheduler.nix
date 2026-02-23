# kube-scheduler — Kubernetes scheduler
#
# Watches for newly created Pods with no assigned node and selects
# a node for them to run on.
{ pkgs, k8sSrc }:

pkgs.buildGoModule {
  pname = "kube-scheduler";
  inherit (k8sSrc) version src;

  vendorHash = null;
  subPackages = [ "cmd/kube-scheduler" ];
  ldflags = k8sSrc.ldflags;
  doCheck = false;

  meta = {
    description = "Kubernetes scheduler";
    homepage = "https://kubernetes.io/docs/reference/command-line-tools-reference/kube-scheduler/";
    license = pkgs.lib.licenses.asl20;
    mainProgram = "kube-scheduler";
    platforms = pkgs.lib.platforms.linux;
  };
}
