use anyhow::Result;
use std::process::ExitCode;
use tracing::{info, warn};

use crate::config::ClusterConfig;
use crate::{health, up, vm};

/// Run a continuous health monitoring daemon.
///
/// On start, if the VM is not running, brings up the cluster.
/// Then loops: sleep for interval, check health, restart on N consecutive failures.
/// Handles SIGTERM/SIGINT for graceful shutdown.
pub async fn run(
    config: &ClusterConfig,
    interval: u64,
    max_failures: u32,
) -> Result<ExitCode> {
    info!(
        cluster = %config.name,
        interval = interval,
        max_failures = max_failures,
        "starting daemon"
    );

    // Ensure the cluster is running on daemon start
    if !vm::is_running(&config.name)? {
        info!("VM not running, bringing up cluster");
        let code = up::run(config, false, false).await?;
        if code != ExitCode::SUCCESS {
            anyhow::bail!("failed to bring up cluster on daemon start");
        }
    }

    let mut consecutive_failures: u32 = 0;

    loop {
        tokio::select! {
            _ = tokio::time::sleep(tokio::time::Duration::from_secs(interval)) => {
                // Perform health check
                let summary = health::check_all(&config.name, config.api_port).await;

                let all_healthy = summary.vm_running
                    && summary.api.healthy
                    && summary.node.healthy;

                if all_healthy {
                    if consecutive_failures > 0 {
                        info!("cluster recovered, resetting failure count");
                    }
                    consecutive_failures = 0;
                } else {
                    consecutive_failures += 1;
                    warn!(
                        failures = consecutive_failures,
                        vm = summary.vm_running,
                        api = summary.api.healthy,
                        node = summary.node.healthy,
                        "health check failed"
                    );

                    if consecutive_failures >= max_failures {
                        warn!(
                            "reached {} consecutive failures, restarting cluster",
                            max_failures
                        );

                        // Attempt restart
                        consecutive_failures = 0;

                        // If VM is still running, try graceful shutdown first
                        if vm::is_running(&config.name).unwrap_or(false) {
                            info!("stopping unhealthy VM");
                            if let Err(e) = crate::down::run(config, config.shutdown_timeout_secs).await {
                                warn!(error = %e, "graceful shutdown failed, continuing with restart");
                                vm::cleanup_pid_file(&config.name)?;
                            }
                        }

                        info!("restarting cluster");
                        match up::run(config, false, false).await {
                            Ok(ExitCode::SUCCESS) => {
                                info!("cluster restarted successfully");
                            }
                            Ok(_) => {
                                warn!("cluster restart returned non-success");
                            }
                            Err(e) => {
                                warn!(error = %e, "cluster restart failed");
                            }
                        }
                    }
                }
            }
            _ = tokio::signal::ctrl_c() => {
                info!("received shutdown signal, exiting daemon");
                println!("Daemon shutting down.");
                return Ok(ExitCode::SUCCESS);
            }
        }
    }
}
