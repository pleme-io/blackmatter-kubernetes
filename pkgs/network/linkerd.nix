# Linkerd CLI — Linkerd service mesh CLI (stable channel)
{ mkGoTool, pkgs }:

let
  version = "2.14.9";
  channel = "stable";
  src = pkgs.fetchFromGitHub {
    owner = "linkerd";
    repo = "linkerd2";
    rev = "${channel}-${version}";
    sha256 = "135x5q0a8knckbjkag2xqcr76zy49i57zf2hlsa70iknynq33ys7";
  };
in mkGoTool pkgs {
  pname = "linkerd";
  inherit version src;
  vendorHash = "sha256-bGl8IZppwLDS6cRO4HmflwIOhH3rOhE/9slJATe+onI=";
  subPackages = [ "cli" ];
  tags = [ "prod" ];
  versionLdflags = {
    "github.com/linkerd/linkerd2/pkg/version.Version" = "${channel}-${version}";
  };
  extraBuildInputs = [ pkgs.installShellFiles ];
  extraAttrs = {
    preBuild = ''
      env GOFLAGS="" go generate ./pkg/charts/static
      env GOFLAGS="" go generate ./jaeger/static
      env GOFLAGS="" go generate ./multicluster/static
      env GOFLAGS="" go generate ./viz/static
    '';
  };
  extraPostInstall = ''
    mv $out/bin/cli $out/bin/linkerd
    installShellCompletion --cmd linkerd \
      --bash <($out/bin/linkerd completion bash) \
      --zsh <($out/bin/linkerd completion zsh) \
      --fish <($out/bin/linkerd completion fish)
  '';
  description = "Linkerd service mesh CLI";
  homepage = "https://linkerd.io/";
}
