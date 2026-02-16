# Blackmatter Kubernetes - aggregates kubernetes + k9s components
{ ... }: {
  imports = [
    ./kubernetes
  ];
  # k9s is imported by kubernetes/default.nix via ./k9s
}
