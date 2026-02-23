# kube-apiserver — Kubernetes API server
#
# Stateless component that validates and configures data for API objects.
# Serves as the front-end for the cluster's shared state (etcd is separate).
{ pkgs, k8sSrc }:

pkgs.buildGoModule {
  pname = "kube-apiserver";
  inherit (k8sSrc) version src;

  vendorHash = null;
  subPackages = [ "cmd/kube-apiserver" ];
  ldflags = k8sSrc.ldflags;
  doCheck = false;

  meta = {
    description = "Kubernetes API server";
    homepage = "https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/";
    license = pkgs.lib.licenses.asl20;
    mainProgram = "kube-apiserver";
    platforms = pkgs.lib.platforms.linux;
  };
}
