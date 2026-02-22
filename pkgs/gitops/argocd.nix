# Argo CD — Declarative GitOps continuous delivery
{ mkGoTool, pkgs }:
let
  version = "3.3.0";
  src = pkgs.fetchFromGitHub {
    owner = "argoproj";
    repo = "argo-cd";
    rev = "v${version}";
    hash = "sha256-FvN4JCG/5SxpnmdEH9X1sMX5dNlp/x0ALNysv+LWroU=";
  };
in mkGoTool pkgs {
  pname = "argocd";
  inherit version src;
  vendorHash = "sha256-UYDGt7iTyDlq3lKEZAqFchO0IYV5kVlfbegWaHsA1Og=";
  proxyVendor = true;
  subPackages = [ "cmd" ];
  versionLdflags = {
    "github.com/argoproj/argo-cd/v3/common.version" = version;
    "github.com/argoproj/argo-cd/v3/common.buildDate" = "1970-01-01T00:00:00Z";
  };
  # Rename binary THEN generate completions — order matters
  extraBuildInputs = [ pkgs.installShellFiles ];
  extraPostInstall = ''
    mv $out/bin/cmd $out/bin/argocd
    installShellCompletion --cmd argocd \
      --bash <($out/bin/argocd completion bash) \
      --zsh <($out/bin/argocd completion zsh) \
      --fish <($out/bin/argocd completion fish)
  '';
  description = "Declarative GitOps continuous delivery for Kubernetes";
  homepage = "https://argoproj.github.io/cd/";
}
