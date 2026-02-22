# Security & Policy tools — built from source with our Go toolchain
{ mkGoTool, pkgs }:

{
  kubeseal = import ./kubeseal.nix { inherit mkGoTool pkgs; };
  trivy = import ./trivy.nix { inherit mkGoTool pkgs; };
  grype = import ./grype.nix { inherit mkGoTool pkgs; };
  cosign = import ./cosign.nix { inherit mkGoTool pkgs; };
  kyverno = import ./kyverno.nix { inherit mkGoTool pkgs; };
  open-policy-agent = import ./open-policy-agent.nix { inherit pkgs; };
  conftest = import ./conftest.nix { inherit mkGoTool pkgs; };
  falcoctl = import ./falcoctl.nix { inherit mkGoTool pkgs; };
  kubescape = import ./kubescape.nix { inherit mkGoTool pkgs; };
  kube-linter = import ./kube-linter.nix { inherit mkGoTool pkgs; };
  kubeconform = import ./kubeconform.nix { inherit mkGoTool pkgs; };
  step-cli = import ./step-cli.nix { inherit mkGoTool pkgs; };
}
