# FluxCD — GitOps toolkit for Kubernetes
{ mkGoTool, pkgs }:

let
  version = "2.7.5";
  src = pkgs.fetchFromGitHub {
    owner = "fluxcd";
    repo = "flux2";
    rev = "v${version}";
    hash = "sha256-vTb1YE73xxCC4GlR6UW5Ibu+ck+N+KKYUg50csb7eUA=";
  };

  manifests = pkgs.fetchurl {
    url = "https://github.com/fluxcd/flux2/releases/download/v${version}/manifests.tar.gz";
    hash = "sha256-gFY5+hAYifJmit87XrKMBzcSBPR4kyIopH5y3QEGxTE=";
  };
in mkGoTool pkgs {
  pname = "fluxcd";
  inherit version src;
  vendorHash = "sha256-AgWDvlXVZXXprWCeoNeAMDb6LeYfa9yG5afc7TNISQs=";
  subPackages = [ "cmd/flux" ];
  versionLdflags = {
    "main.VERSION" = version;
  };
  completions = { install = true; command = "flux"; };
  extraAttrs = {
    postUnpack = ''
      mkdir -p source/cmd/flux/manifests
      tar xf ${manifests} -C source/cmd/flux/manifests
      # Remove test that requires network access
      rm -f source/cmd/flux/create_secret_git_test.go
    '';
    env.HOME = "$TMPDIR";
  };
  description = "GitOps toolkit for Kubernetes";
  homepage = "https://fluxcd.io/";
}
