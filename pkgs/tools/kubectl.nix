# Kubectl — Kubernetes CLI
#
# kubectl lives in the Kubernetes monorepo. We use buildGoModule directly
# with subPackages to build only cmd/kubectl, avoiding the full Makefile
# machinery. Version ldflags are replicated from hack/lib/version.sh.
{ pkgs }:

let
  version = "1.35.0";
  src = pkgs.fetchFromGitHub {
    owner = "kubernetes";
    repo = "kubernetes";
    tag = "v${version}";
    hash = "sha256-AT1/4RhnVK/mAoNVqPIfSwbzD8VNRqKumOpE0fidJ74=";
  };

  # Version ldflags matching upstream hack/lib/version.sh
  versionPkg = "k8s.io/component-base/version";
  majorMinor = builtins.match "([0-9]+)\\.([0-9]+)\\..+" version;
  gitMajor = builtins.elemAt majorMinor 0;
  gitMinor = builtins.elemAt majorMinor 1;
in pkgs.buildGoModule {
  pname = "kubectl";
  inherit version src;

  vendorHash = null; # vendored in-tree

  subPackages = [ "cmd/kubectl" ];

  ldflags = [
    "-s" "-w"
    "-X ${versionPkg}.gitVersion=v${version}"
    "-X ${versionPkg}.gitMajor=${gitMajor}"
    "-X ${versionPkg}.gitMinor=${gitMinor}"
    "-X ${versionPkg}.gitTreeState=clean"
    "-X ${versionPkg}.buildDate=1970-01-01T00:00:00Z"
  ];

  doCheck = false;

  nativeBuildInputs = [ pkgs.installShellFiles ];

  postInstall = ''
    installShellCompletion --cmd kubectl \
      --bash <($out/bin/kubectl completion bash) \
      --zsh <($out/bin/kubectl completion zsh) \
      --fish <($out/bin/kubectl completion fish)
  '';

  meta = {
    description = "Kubernetes CLI";
    homepage = "https://kubernetes.io/docs/reference/kubectl/";
    license = pkgs.lib.licenses.asl20;
    mainProgram = "kubectl";
    platforms = pkgs.lib.platforms.unix;
  };
}
