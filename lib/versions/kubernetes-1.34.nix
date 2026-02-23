# Shared component versions for Kubernetes 1.34 track
#
# These versions are consumed by both k3s and vanilla k8s builds,
# ensuring version parity across distributions.
{
  kubernetesVersion = "1.34.3";
  etcdVersion = "3.6.7";
  containerdVersion = "2.1.5";
  runcVersion = "1.2.6";
  cniPluginsVersion = "1.8.0";
  crictlVersion = "1.34.0";
  pauseVersion = "3.11";
}
