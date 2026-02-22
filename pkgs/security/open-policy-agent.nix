# OPA — Open Policy Agent
# NOTE: Uses buildGoModule directly because binary is "opa" but pname is "open-policy-agent"
{ pkgs }:
let
  version = "1.13.1";
  src = pkgs.fetchFromGitHub {
    owner = "open-policy-agent";
    repo = "opa";
    rev = "v${version}";
    hash = "sha256-MBfzoaIZY3u4PtchCzquhrkasjwnARag/UCc5JBTfmw=";
  };
in pkgs.buildGoModule {
  pname = "open-policy-agent";
  inherit version src;
  vendorHash = "sha256-Jn0vi1Ihyeog/LaUcuu/V9dd8l9LSdRSbtH1GPJrT50=";
  subPackages = [ "." ];
  doCheck = false;

  ldflags = [
    "-s" "-w"
    "-X github.com/open-policy-agent/opa/version.Version=${version}"
  ];

  nativeBuildInputs = [ pkgs.installShellFiles ];
  postInstall = ''
    installShellCompletion --cmd opa \
      --bash <($out/bin/opa completion bash) \
      --zsh <($out/bin/opa completion zsh) \
      --fish <($out/bin/opa completion fish)
  '';

  meta = {
    description = "Open Policy Agent — policy engine for cloud-native environments";
    homepage = "https://www.openpolicyagent.org/";
    license = pkgs.lib.licenses.asl20;
    mainProgram = "opa";
  };
}
