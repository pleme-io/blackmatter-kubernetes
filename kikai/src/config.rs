use anyhow::{Context, Result};
use std::path::PathBuf;

/// Configuration for a k3s cluster lifecycle.
#[derive(serde::Serialize)]
pub struct ClusterConfig {
    /// Cluster name (e.g., ryn-k3s)
    pub name: String,
    /// Number of vCPUs
    pub cpus: u32,
    /// Memory in MiB
    pub memory: u32,
    /// Data disk size (sparse) e.g. "50G"
    pub disk_size: String,
    /// Host port for K8s API (forwarded to guest 6443)
    pub api_port: u16,
    /// Host port for SSH (forwarded to guest 22)
    pub ssh_port: u16,
    /// Path to SOPS-encrypted secrets file
    pub secrets_file: String,
    /// Path to .sops.yaml config
    pub sops_yaml: String,
    /// Path to nix flake (for building the image)
    pub nix_flake: String,
    /// Boot/health-check timeout in seconds (how long to wait for cluster to become healthy)
    pub boot_timeout_secs: u64,
    /// Shutdown timeout in seconds (how long to wait for graceful VM shutdown)
    pub shutdown_timeout_secs: u64,
    /// Health check polling interval in seconds (base interval for daemon health loop)
    pub health_interval_secs: u64,
}

impl Default for ClusterConfig {
    fn default() -> Self {
        Self {
            name: String::new(),
            cpus: 4,
            memory: 8192,
            disk_size: "50G".to_string(),
            api_port: 6443,
            ssh_port: 2222,
            secrets_file: "secrets.yaml".to_string(),
            sops_yaml: ".sops.yaml".to_string(),
            nix_flake: ".".to_string(),
            boot_timeout_secs: 300,
            shutdown_timeout_secs: 120,
            health_interval_secs: 2,
        }
    }
}

/// Return the data directory for a cluster: `~/.local/share/kikai/<cluster>`
pub fn data_dir(cluster: &str) -> Result<PathBuf> {
    let home = std::env::var("HOME").context("HOME not set")?;
    Ok(PathBuf::from(home)
        .join(".local/share/kikai")
        .join(cluster))
}

/// Return the PID file path for a cluster VM.
pub fn pid_file(cluster: &str) -> Result<PathBuf> {
    Ok(data_dir(cluster)?.join("vm.pid"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_config() {
        let cfg = ClusterConfig::default();
        assert_eq!(cfg.cpus, 4);
        assert_eq!(cfg.memory, 8192);
        assert_eq!(cfg.disk_size, "50G");
        assert_eq!(cfg.api_port, 6443);
        assert_eq!(cfg.ssh_port, 2222);
        assert_eq!(cfg.boot_timeout_secs, 300);
        assert_eq!(cfg.shutdown_timeout_secs, 120);
        assert_eq!(cfg.health_interval_secs, 2);
    }

    #[test]
    fn test_data_dir_format() {
        std::env::set_var("HOME", "/tmp/test-home");
        let dir = data_dir("test-cluster").unwrap();
        assert_eq!(
            dir.to_str().unwrap(),
            "/tmp/test-home/.local/share/kikai/test-cluster"
        );
    }

    #[test]
    fn test_pid_file_format() {
        std::env::set_var("HOME", "/tmp/test-home");
        let pid = pid_file("test-cluster").unwrap();
        assert_eq!(
            pid.to_str().unwrap(),
            "/tmp/test-home/.local/share/kikai/test-cluster/vm.pid"
        );
    }

    #[test]
    fn test_cluster_config_serializes_to_json() {
        let cfg = ClusterConfig::default();
        let json = serde_json::to_string(&cfg).unwrap();
        assert!(json.contains("\"cpus\":4"));
        assert!(json.contains("\"disk_size\":\"50G\""));
        assert!(json.contains("\"api_port\":6443"));
    }

    #[test]
    fn test_default_string_fields() {
        let cfg = ClusterConfig::default();
        assert_eq!(cfg.secrets_file, "secrets.yaml");
        assert_eq!(cfg.sops_yaml, ".sops.yaml");
        assert_eq!(cfg.nix_flake, ".");
        assert!(cfg.name.is_empty());
    }
}
