# Blackmatter Kubernetes - home-manager module aggregator
{ ... }: {
  imports = [
    ./kubernetes
    ./kikai
  ];
}
