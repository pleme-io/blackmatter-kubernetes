# kind — Kubernetes IN Docker (local cluster management)
{ mkGoTool, pkgs }:
let
  version = "0.31.0";
  src = pkgs.fetchFromGitHub {
    owner = "kubernetes-sigs";
    repo = "kind";
    rev = "v${version}";
    hash = "sha256-3icwtfwlSkYOEw9bzEhKJC7OtE1lnBjZSYp+cC/2XNc=";
  };
in mkGoTool pkgs {
  pname = "kind";
  inherit version src;
  vendorHash = "sha256-tRpylYpEGF6XqtBl7ESYlXKEEAt+Jws4x4VlUVW8SNI=";
  subPackages = [ "." ];
  versionLdflags = {
    "sigs.k8s.io/kind/pkg/cmd/kind/version.GitVersion" = "v${version}";
  };
  completions = { install = true; command = "kind"; };
  description = "Kubernetes IN Docker — local clusters for testing";
  homepage = "https://kind.sigs.k8s.io/";
}
