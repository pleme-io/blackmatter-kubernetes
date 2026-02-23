# crictl — CRI CLI for Kubernetes container runtimes
#
# Standalone crictl binary for debugging container runtimes.
# In k3s, crictl is embedded via symlink; for vanilla k8s, it's separate.
{ pkgs, crictlVersion }:

let
  version = crictlVersion;

  hashes = {
    "1.29.0" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    "1.31.0" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    "1.31.1" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    "1.32.0" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    "1.34.0" = "sha256-nWbxPw8lz1FYLHXJ2G4kzOl5nBPXSl4nEJ9KgzS/wmA=";
    "1.35.0" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
in pkgs.buildGoModule {
  pname = "crictl";
  inherit version;

  src = pkgs.fetchFromGitHub {
    owner = "kubernetes-sigs";
    repo = "cri-tools";
    rev = "v${version}";
    hash = hashes.${version};
  };

  vendorHash = null; # vendored in-tree

  subPackages = [ "cmd/crictl" ];

  ldflags = [
    "-s" "-w"
    "-X github.com/kubernetes-sigs/cri-tools/pkg/version.Version=v${version}"
  ];

  doCheck = false;

  nativeBuildInputs = [ pkgs.installShellFiles ];

  postInstall = ''
    installShellCompletion --cmd crictl \
      --bash <($out/bin/crictl completion bash) \
      --zsh <($out/bin/crictl completion zsh)
  '';

  meta = {
    description = "CLI for CRI-compatible container runtimes";
    homepage = "https://github.com/kubernetes-sigs/cri-tools";
    license = pkgs.lib.licenses.asl20;
    mainProgram = "crictl";
    platforms = pkgs.lib.platforms.linux;
  };
}
