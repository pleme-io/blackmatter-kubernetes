# kube-controller-manager — Kubernetes controller manager
#
# Runs controller loops that regulate cluster state (node, job, endpoint,
# service account, replication controllers, etc.).
{ pkgs, k8sSrc }:

pkgs.buildGoModule {
  pname = "kube-controller-manager";
  inherit (k8sSrc) version src;

  vendorHash = null;
  subPackages = [ "cmd/kube-controller-manager" ];
  ldflags = k8sSrc.ldflags;
  doCheck = false;

  meta = {
    description = "Kubernetes controller manager";
    homepage = "https://kubernetes.io/docs/reference/command-line-tools-reference/kube-controller-manager/";
    license = pkgs.lib.licenses.asl20;
    mainProgram = "kube-controller-manager";
    platforms = pkgs.lib.platforms.linux;
  };
}
