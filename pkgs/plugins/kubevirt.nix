# kubevirt (virtctl) — KubeVirt CLI for VM management
# NOTE: Uses buildGoModule directly because mainProgram differs from pname
{ pkgs }:
let
  version = "1.7.0";
  src = pkgs.fetchFromGitHub {
    owner = "kubevirt";
    repo = "kubevirt";
    rev = "v${version}";
    hash = "sha256-0dfZbhcFSIU9TFxQ3UT8Sz+tgeiqVke+RxVwlxw49Hk=";
  };
in pkgs.buildGoModule {
  pname = "kubevirt";
  inherit version src;
  vendorHash = null;
  subPackages = [ "cmd/virtctl" ];
  tags = [ "selinux" ];
  doCheck = false;

  ldflags = [
    "-s" "-w"
    "-X kubevirt.io/client-go/version.gitCommit=v${version}"
    "-X kubevirt.io/client-go/version.gitTreeState=clean"
    "-X kubevirt.io/client-go/version.gitVersion=v${version}"
  ];

  nativeBuildInputs = [ pkgs.installShellFiles ];
  postInstall = ''
    installShellCompletion --cmd virtctl \
      --bash <($out/bin/virtctl completion bash) \
      --fish <($out/bin/virtctl completion fish) \
      --zsh <($out/bin/virtctl completion zsh)
  '';

  meta = {
    description = "Client tool for KubeVirt VM management";
    homepage = "https://kubevirt.io/";
    license = pkgs.lib.licenses.asl20;
    mainProgram = "virtctl";
  };
}
