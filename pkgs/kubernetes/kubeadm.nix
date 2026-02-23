# kubeadm — Kubernetes cluster bootstrap tool
#
# Initializes control planes and joins workers to the cluster.
{ pkgs, k8sSrc }:

pkgs.buildGoModule {
  pname = "kubeadm";
  inherit (k8sSrc) version src;

  vendorHash = null;
  subPackages = [ "cmd/kubeadm" ];
  ldflags = k8sSrc.ldflags;
  doCheck = false;

  nativeBuildInputs = [ pkgs.installShellFiles ];

  postInstall = ''
    installShellCompletion --cmd kubeadm \
      --bash <($out/bin/kubeadm completion bash) \
      --zsh <($out/bin/kubeadm completion zsh)
  '';

  meta = {
    description = "Kubernetes cluster bootstrap tool";
    homepage = "https://kubernetes.io/docs/reference/setup-tools/kubeadm/";
    license = pkgs.lib.licenses.asl20;
    mainProgram = "kubeadm";
    platforms = pkgs.lib.platforms.linux;
  };
}
