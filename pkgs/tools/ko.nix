# Ko — Build and deploy Go applications to Kubernetes
{ mkGoTool, pkgs }:
let
  version = "0.18.1";
  src = pkgs.fetchFromGitHub {
    owner = "ko-build";
    repo = "ko";
    rev = "v${version}";
    hash = "sha256-o/Hin6GDFki1ynZ/rDQOhcNUTtQVvXZTAApxAaerRCU=";
  };
in mkGoTool pkgs {
  pname = "ko";
  inherit version src;
  vendorHash = "sha256-gYDYKNLTmJT0JvQ4wi/5p/3YmaaS4Re/wFqZxRbRVpg=";
  subPackages = [ "." ];
  extraAttrs = { env.CGO_ENABLED = "0"; };
  versionLdflags = {
    "github.com/google/ko/pkg/commands.Version" = version;
  };
  completions = { install = true; command = "ko"; };
  description = "Build and deploy Go applications to Kubernetes";
  homepage = "https://ko.build/";
}
