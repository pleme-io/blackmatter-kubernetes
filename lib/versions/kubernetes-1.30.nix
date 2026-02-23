# Shared component versions for Kubernetes 1.30 track
#
# These versions are consumed by both k3s and vanilla k8s builds,
# ensuring version parity across distributions.
#
# Status: EOL (2025-06-28)
{
  kubernetesVersion = "1.30.14";
  etcdVersion = "3.5.15";
  containerdVersion = "1.7.27";
  runcVersion = "1.2.6";
  cniPluginsVersion = "1.4.0";
  crictlVersion = "1.29.0";
  pauseVersion = "3.9";
}
