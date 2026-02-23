# Shared component versions for Kubernetes 1.33 track
#
# These versions are consumed by both k3s and vanilla k8s builds,
# ensuring version parity across distributions.
#
# Status: Supported
{
  kubernetesVersion = "1.33.8";
  etcdVersion = "3.5.24";
  containerdVersion = "2.1.5";
  runcVersion = "1.3.4";
  cniPluginsVersion = "1.6.2";
  crictlVersion = "1.32.0";
  pauseVersion = "3.10";
}
