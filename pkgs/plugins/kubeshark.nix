# kubeshark — API traffic viewer for Kubernetes
{ mkGoTool, pkgs }:
let
  version = "52.10.3";
  src = pkgs.fetchFromGitHub {
    owner = "kubeshark";
    repo = "kubeshark";
    rev = "v${version}";
    hash = "sha256-n7AYUms6fn25UinLd5xFG2DfcpJU0/pR4JF3i1VY1hM=";
  };
  t = "github.com/kubeshark/kubeshark";
in mkGoTool pkgs {
  pname = "kubeshark";
  inherit version src;
  vendorHash = "sha256-4s1gxJo2w5BibZ9CJP7Jl9Z8Zzo8WpBokBnRN+zp8b4=";
  ldflags = [
    "-s" "-w"
    "-X ${t}/misc.GitCommitHash=v${version}"
    "-X ${t}/misc.Branch=master"
    "-X ${t}/misc.BuildTimestamp=0"
    "-X ${t}/misc.Platform=unknown"
    "-X ${t}/misc.Ver=${version}"
  ];
  completions = { install = true; command = "kubeshark"; };
  description = "API traffic viewer for Kubernetes";
  homepage = "https://kubeshark.co/";
}
