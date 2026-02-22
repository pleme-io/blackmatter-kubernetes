# Crossplane CLI — Multi-cloud infrastructure management
{ mkGoTool, pkgs }:
let
  version = "2.1.3";
  src = pkgs.fetchFromGitHub {
    owner = "crossplane";
    repo = "crossplane";
    rev = "v${version}";
    hash = "sha256-ODqNay4wmbo770ZBpGSH/Zm2Y2vVmUC6PfTzv9CyZns=";
  };
in mkGoTool pkgs {
  pname = "crossplane-cli";
  inherit version src;
  vendorHash = "sha256-90TwfDBb5COEGqjDIoUrZVWS/N8A14ZxbrvvFVgMTNU=";
  subPackages = [ "cmd/crank" ];
  versionLdflags = {
    "github.com/crossplane/crossplane/internal/version.version" = "v${version}";
  };
  extraBuildInputs = [ pkgs.installShellFiles ];
  extraPostInstall = ''
    mv $out/bin/crank $out/bin/crossplane
    installShellCompletion --cmd crossplane \
      --bash <($out/bin/crossplane completion bash) \
      --zsh <($out/bin/crossplane completion zsh) \
      --fish <($out/bin/crossplane completion fish)
  '';
  description = "Crossplane multi-cloud infrastructure management CLI";
  homepage = "https://crossplane.io/";
}
