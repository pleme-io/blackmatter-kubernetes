# Shared component versions for Kubernetes 1.31 track
#
# These versions are consumed by both k3s and vanilla k8s builds,
# ensuring version parity across distributions.
#
# Status: EOL (2025-10-28)
{
  kubernetesVersion = "1.31.14";
  etcdVersion = "3.5.24";
  containerdVersion = "2.1.5";
  runcVersion = "1.2.8";
  cniPluginsVersion = "1.5.1";
  crictlVersion = "1.31.0";
  pauseVersion = "3.10";
}
