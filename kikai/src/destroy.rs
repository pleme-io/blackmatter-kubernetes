use anyhow::{Context, Result};
use std::process::ExitCode;
use tracing::info;

use crate::config::{self, ClusterConfig};
use crate::{down, sops, vm};

/// Destroy a cluster: stop the VM, remove data directory, optionally remove secrets.
pub async fn run(
    config: &ClusterConfig,
    remove_secrets: bool,
    force: bool,
) -> Result<ExitCode> {
    let data_dir = config::data_dir(&config.name)?;

    // Confirm unless --force
    if !force {
        println!(
            "This will destroy cluster '{}' and remove all data at {}.",
            config.name,
            data_dir.display()
        );
        println!("Use --force to skip this confirmation.");
        return Ok(ExitCode::FAILURE);
    }

    // If VM is running, shut it down first
    if vm::is_running(&config.name)? {
        info!(cluster = %config.name, "VM is running, shutting down first");
        let code = down::run(config, config.shutdown_timeout_secs).await?;
        if code != ExitCode::SUCCESS {
            tracing::warn!("graceful shutdown returned non-success, proceeding with destroy");
        }
    }

    // Remove data directory
    if data_dir.exists() {
        info!(path = %data_dir.display(), "removing data directory");
        std::fs::remove_dir_all(&data_dir)
            .with_context(|| format!("removing {}", data_dir.display()))?;
        println!("Removed data directory: {}", data_dir.display());
    } else {
        println!("Data directory does not exist: {}", data_dir.display());
    }

    // Clean up PID file (may be outside data_dir in some configurations)
    vm::cleanup_pid_file(&config.name)?;

    if remove_secrets {
        let key_path = format!("[\"clusters\"][\"{}\"]", config.name);
        info!(key_path = %key_path, "removing cluster secrets from SOPS");
        match sops::remove(&config.secrets_file, &key_path).await {
            Ok(()) => {
                println!("Removed cluster secrets from SOPS.");
            }
            Err(e) => {
                tracing::warn!(error = %e, "failed to remove cluster secrets from SOPS");
                println!("WARNING: Could not remove secrets automatically: {e}");
                println!("To remove secrets manually:");
                println!(
                    "  sops unset {} '{}'",
                    config.secrets_file, key_path
                );
            }
        }
    }

    println!();
    println!("Cluster '{}' destroyed.", config.name);
    Ok(ExitCode::SUCCESS)
}
