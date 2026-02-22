# Velero — Kubernetes backup and disaster recovery
# NOTE: Uses buildGoModule directly because it needs excludedPackages
{ pkgs }:
let
  version = "1.17.2";
  src = pkgs.fetchFromGitHub {
    owner = "vmware-tanzu";
    repo = "velero";
    rev = "v${version}";
    hash = "sha256-cDOsLwSp7VtHeylgDGhotBn1VN2HzBEq1kZsx7wN2r8=";
  };
in pkgs.buildGoModule {
  pname = "velero";
  inherit version src;
  vendorHash = "sha256-1ikbyWXK3jL4I+FxiqOsvPvqk+/DIndc4myTajDxFko=";

  excludedPackages = [
    "issue-template-gen"
    "release-tools"
    "v1"
    "velero-restic-restore-helper"
  ];

  ldflags = [
    "-s" "-w"
    "-X github.com/vmware-tanzu/velero/pkg/buildinfo.Version=v${version}"
    "-X github.com/vmware-tanzu/velero/pkg/buildinfo.ImageRegistry=velero"
    "-X github.com/vmware-tanzu/velero/pkg/buildinfo.GitTreeState=clean"
    "-X github.com/vmware-tanzu/velero/pkg/buildinfo.GitSHA=none"
  ];

  doCheck = false;

  nativeBuildInputs = [ pkgs.installShellFiles ];
  postInstall = ''
    installShellCompletion --cmd velero \
      --bash <($out/bin/velero completion bash) \
      --zsh <($out/bin/velero completion zsh)
  '';

  meta = {
    description = "Kubernetes backup, restore, and disaster recovery";
    homepage = "https://velero.io/";
    license = pkgs.lib.licenses.asl20;
    mainProgram = "velero";
  };
}
