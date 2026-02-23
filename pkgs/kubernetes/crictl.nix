# crictl — CRI CLI for Kubernetes container runtimes
#
# Standalone crictl binary for debugging container runtimes.
# In k3s, crictl is embedded via symlink; for vanilla k8s, it's separate.
{ mkRuntimeComponent, crictlVersion }:

mkRuntimeComponent {
  pname = "crictl";
  version = crictlVersion;
  owner = "kubernetes-sigs";
  repo = "cri-tools";
  hashes = {
    "1.29.0" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    "1.31.0" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    "1.31.1" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    "1.32.0" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    "1.34.0" = "sha256-nWbxPw8lz1FYLHXJ2G4kzOl5nBPXSl4nEJ9KgzS/wmA=";
    "1.35.0" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
  vendorHash = null;
  subPackages = [ "cmd/crictl" ];
  ldflags = [
    "-s" "-w"
    "-X github.com/kubernetes-sigs/cri-tools/pkg/version.Version=v${crictlVersion}"
  ];
  completions = { install = true; command = "crictl"; };
  description = "CLI for CRI-compatible container runtimes";
  homepage = "https://github.com/kubernetes-sigs/cri-tools";
}
