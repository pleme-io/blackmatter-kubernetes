# step-cli — Zero trust certificate authority CLI
# NOTE: Binary is named "step" (not "step-cli" or "cli"). The smallstep/cli
# module produces a binary called "step" via Go package naming.
{ mkGoTool, pkgs }:
let
  version = "0.29.0";
  src = pkgs.fetchFromGitHub {
    owner = "smallstep";
    repo = "cli";
    rev = "v${version}";
    hash = "sha256-JUJeW9/m3fTaDfUublFDSQ3R5gT6Xvn97c5VokBvZ30=";
    postFetch = ''
      rm -f $out/.VERSION
    '';
  };
in mkGoTool pkgs {
  pname = "step-cli";
  inherit version src;
  vendorHash = "sha256-0ZnuqyB2/fgfADCvYHj2o4PFwf0Btn6+GouXCPqzKmk=";
  versionLdflags = {
    "main.Version" = version;
  };
  # Binary is "step", not "cli" — rename and then generate completions
  extraBuildInputs = [ pkgs.installShellFiles ];
  extraPostInstall = ''
    # Go produces binary named after module path last segment
    # Rename if needed (binary may already be "step" on some Go versions)
    if [ -f $out/bin/cli ] && [ ! -f $out/bin/step ]; then
      mv $out/bin/cli $out/bin/step
    fi
    installShellCompletion --cmd step \
      --bash <($out/bin/step completion bash) \
      --zsh <($out/bin/step completion zsh) \
      --fish <($out/bin/step completion fish)
  '';
  description = "Zero trust swiss army knife for X509, OAuth, JWT, OATH OTP";
  homepage = "https://smallstep.com/cli/";
}
