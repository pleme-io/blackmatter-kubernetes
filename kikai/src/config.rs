use anyhow::{Context, Result};
use std::path::PathBuf;

/// Configuration for a k3s cluster lifecycle.
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
