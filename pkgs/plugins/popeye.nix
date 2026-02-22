# Popeye — Kubernetes cluster resource sanitizer
{ mkGoTool, pkgs }:
let
  version = "0.22.1";
  src = pkgs.fetchFromGitHub {
    owner = "derailed";
    repo = "popeye";
    rev = "v${version}";
    hash = "sha256-CbVYQIE7kjUah+SDEjs5Qz+n4+f3HriQNxYPqDcdr/I=";
  };
in mkGoTool pkgs {
  pname = "popeye";
  inherit version src;
  vendorHash = "sha256-Xhn1iOqzCY8fW2lODXwqY4XQZTAPWXaZ0XM5j02bnCs=";
  versionLdflags = {
    "github.com/derailed/popeye/cmd.version" = version;
    "github.com/derailed/popeye/cmd.commit" = version;
  };
  completions = { install = true; command = "popeye"; };
  description = "Kubernetes cluster resource sanitizer";
  homepage = "https://github.com/derailed/popeye";
}
