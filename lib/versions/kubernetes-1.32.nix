# Shared component versions for Kubernetes 1.32 track
#
# These versions are consumed by both k3s and vanilla k8s builds,
# ensuring version parity across distributions.
#
# Status: EOL (2026-02-28)
{
  kubernetesVersion = "1.32.12";
  etcdVersion = "3.5.24";
  containerdVersion = "2.1.5";
  runcVersion = "1.2.9";
  cniPluginsVersion = "1.6.0";
  crictlVersion = "1.31.1";
  pauseVersion = "3.10";
}
