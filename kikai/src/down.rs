use anyhow::Result;
use std::process::ExitCode;
use tracing::info;

use crate::config::ClusterConfig;
use crate::vm;

/// Gracefully shut down a running cluster VM.
///
/// Sends `shutdown -h now` via SSH and waits for the VM process to exit.
/// Cleans up the PID file after the process exits.
pub async fn run(config: &ClusterConfig, timeout: u64) -> Result<ExitCode> {
    if !vm::is_running(&config.name)? {
        info!(cluster = %config.name, "VM is not running");
        println!("Cluster '{}' is not running.", config.name);
        // Clean up stale PID file if present
        vm::cleanup_pid_file(&config.name)?;
        return Ok(ExitCode::SUCCESS);
    }

    let pid = vm::read_pid(&config.name)?;
    println!(
        "Shutting down cluster '{}' (PID {:?}, timeout: {}s)...",
        config.name, pid, timeout
    );

    vm::stop(config, timeout).await?;

    println!("Cluster '{}' shut down successfully.", config.name);
    Ok(ExitCode::SUCCESS)
}
