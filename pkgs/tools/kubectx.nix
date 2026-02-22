# Kubectx — Kubernetes context/namespace switcher
{ mkGoTool, pkgs }:

let
  version = "0.9.5";
  src = pkgs.fetchFromGitHub {
    owner = "ahmetb";
    repo = "kubectx";
    rev = "v${version}";
    hash = "sha256-HVmtUhdMjbkyMpTgbsr5Mm286F9Q7zbc5rOxi7OBZEg=";
  };
in mkGoTool pkgs {
  pname = "kubectx";
  inherit version src;
  vendorHash = "sha256-3xetjviMuH+Nev12DB2WN2Wnmw1biIDAckUSGVRHQwM=";
  versionLdflags = {
    "main.version" = version;
  };
  extraBuildInputs = [ pkgs.installShellFiles ];
  extraPostInstall = ''
    installShellCompletion --cmd kubectx \
      --bash $src/completion/kubectx.bash \
      --zsh $src/completion/_kubectx.zsh
    installShellCompletion --cmd kubens \
      --bash $src/completion/kubens.bash \
      --zsh $src/completion/_kubens.zsh
  '';
  description = "Kubernetes context and namespace switcher";
  homepage = "https://github.com/ahmetb/kubectx";
}
