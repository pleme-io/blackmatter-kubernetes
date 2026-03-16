use anyhow::Result;
use serde::Serialize;
use tracing::info;

/// Result of a single health check probe.
#[derive(Debug, Clone, Serialize)]
pub struct HealthResult {
    pub healthy: bool,
    pub detail: String,
}

/// Aggregated health summary for a cluster.
#[derive(Debug, Clone, Serialize)]
pub struct HealthSummary {
    pub vm_running: bool,
    pub api: HealthResult,
    pub node: HealthResult,
    pub flux: HealthResult,
    pub pods: HealthResult,
}

/// Check the K8s API server healthz endpoint.
pub async fn check_api(api_port: u16) -> HealthResult {
    let output = tokio::process::Command::new("curl")
        .args([
            "-sk",
            "--connect-timeout",
            "5",
            "--max-time",
            "10",
            &format!("https://localhost:{api_port}/healthz"),
        ])
        .output()
        .await;

    match output {
        Ok(out) if out.status.success() => {
            let body = String::from_utf8_lossy(&out.stdout).trim().to_string();
            if body == "ok" {
                HealthResult {
                    healthy: true,
                    detail: "API server healthy".to_string(),
                }
            } else {
                HealthResult {
                    healthy: false,
                    detail: format!("API server returned: {body}"),
                }
            }
        }
        Ok(out) => HealthResult {
            healthy: false,
            detail: format!(
                "API server unreachable: {}",
                String::from_utf8_lossy(&out.stderr).trim()
            ),
        },
        Err(e) => HealthResult {
            healthy: false,
            detail: format!("curl failed: {e}"),
        },
    }
}

/// Check whether the cluster node is in Ready state.
pub async fn check_node(cluster: &str) -> HealthResult {
    let output = tokio::process::Command::new("kubectl")
        .args([
            "--context",
            cluster,
            "get",
            "nodes",
            "-o",
            "jsonpath={.items[*].status.conditions[?(@.type==\"Ready\")].status}",
        ])
        .output()
        .await;

    match output {
        Ok(out) if out.status.success() => {
            let statuses = String::from_utf8_lossy(&out.stdout).trim().to_string();
            if statuses.contains("True") {
                HealthResult {
                    healthy: true,
                    detail: format!("Node ready: {statuses}"),
                }
            } else {
                HealthResult {
                    healthy: false,
                    detail: format!("Node not ready: {statuses}"),
                }
            }
        }
        Ok(out) => HealthResult {
            healthy: false,
            detail: format!(
                "kubectl failed: {}",
                String::from_utf8_lossy(&out.stderr).trim()
            ),
        },
        Err(e) => HealthResult {
            healthy: false,
            detail: format!("kubectl failed: {e}"),
        },
    }
}

/// Check whether all FluxCD kustomizations are ready.
pub async fn check_flux(cluster: &str) -> HealthResult {
    let output = tokio::process::Command::new("kubectl")
        .args([
            "--context",
            cluster,
            "get",
            "kustomizations",
            "-A",
            "-o",
            "jsonpath={.items[*].status.conditions[?(@.type==\"Ready\")].status}",
        ])
        .output()
        .await;

    match output {
        Ok(out) if out.status.success() => {
            let statuses = String::from_utf8_lossy(&out.stdout).trim().to_string();
            if statuses.is_empty() {
                HealthResult {
                    healthy: false,
                    detail: "No kustomizations found".to_string(),
                }
            } else if statuses.split_whitespace().all(|s| s == "True") {
                HealthResult {
                    healthy: true,
                    detail: "All kustomizations ready".to_string(),
                }
            } else {
                HealthResult {
                    healthy: false,
                    detail: format!("Some kustomizations not ready: {statuses}"),
                }
            }
        }
        Ok(out) => HealthResult {
            healthy: false,
            detail: format!(
                "kubectl failed: {}",
                String::from_utf8_lossy(&out.stderr).trim()
            ),
        },
        Err(e) => HealthResult {
            healthy: false,
            detail: format!("kubectl failed: {e}"),
        },
    }
}

/// Check for pods that are not running/succeeded.
pub async fn check_pods(cluster: &str) -> HealthResult {
    let output = tokio::process::Command::new("kubectl")
        .args([
            "--context",
            cluster,
            "get",
            "pods",
            "-A",
            "--field-selector",
            "status.phase!=Running,status.phase!=Succeeded",
            "-o",
            "jsonpath={.items[*].metadata.name}",
        ])
        .output()
        .await;

    match output {
        Ok(out) if out.status.success() => {
            let unhealthy = String::from_utf8_lossy(&out.stdout).trim().to_string();
            if unhealthy.is_empty() {
                HealthResult {
                    healthy: true,
                    detail: "All pods running or completed".to_string(),
                }
            } else {
                let count = unhealthy.split_whitespace().count();
                HealthResult {
                    healthy: false,
                    detail: format!("{count} unhealthy pod(s): {unhealthy}"),
                }
            }
        }
        Ok(out) => HealthResult {
            healthy: false,
            detail: format!(
                "kubectl failed: {}",
                String::from_utf8_lossy(&out.stderr).trim()
            ),
        },
        Err(e) => HealthResult {
            healthy: false,
            detail: format!("kubectl failed: {e}"),
        },
    }
}

/// Run all health checks and return an aggregated summary.
pub async fn check_all(cluster: &str, api_port: u16) -> HealthSummary {
    let vm_running = crate::vm::is_running(cluster).unwrap_or(false);
    let api = check_api(api_port).await;
    let node = check_node(cluster).await;
    let flux = check_flux(cluster).await;
    let pods = check_pods(cluster).await;

    HealthSummary {
        vm_running,
        api,
        node,
        flux,
        pods,
    }
}

/// Poll until the API server returns healthy, with the given timeout in seconds.
pub async fn wait_for_api(api_port: u16, timeout_secs: u64) -> Result<()> {
    info!(port = api_port, timeout = timeout_secs, "waiting for API server");
    let deadline =
        tokio::time::Instant::now() + tokio::time::Duration::from_secs(timeout_secs);

    loop {
        let result = check_api(api_port).await;
        if result.healthy {
            info!("API server is healthy");
            return Ok(());
        }

        if tokio::time::Instant::now() >= deadline {
            anyhow::bail!(
                "API server not healthy after {}s: {}",
                timeout_secs,
                result.detail
            );
        }

        tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;
    }
}

/// Poll until the cluster node is Ready, with the given timeout in seconds.
pub async fn wait_for_node_ready(cluster: &str, timeout_secs: u64) -> Result<()> {
    info!(cluster = %cluster, timeout = timeout_secs, "waiting for node to be ready");
    let deadline =
        tokio::time::Instant::now() + tokio::time::Duration::from_secs(timeout_secs);

    loop {
        let result = check_node(cluster).await;
        if result.healthy {
            info!("node is ready");
            return Ok(());
        }

        if tokio::time::Instant::now() >= deadline {
            anyhow::bail!(
                "node not ready after {}s: {}",
                timeout_secs,
                result.detail
            );
        }

        tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;
    }
}

/// Poll until all FluxCD kustomizations are Ready, with the given timeout in seconds.
pub async fn wait_for_flux(cluster: &str, timeout_secs: u64) -> Result<()> {
    info!(cluster = %cluster, timeout = timeout_secs, "waiting for flux kustomizations");
    let deadline =
        tokio::time::Instant::now() + tokio::time::Duration::from_secs(timeout_secs);

    loop {
        let result = check_flux(cluster).await;
        if result.healthy {
            info!("all flux kustomizations ready");
            return Ok(());
        }

        if tokio::time::Instant::now() >= deadline {
            anyhow::bail!(
                "flux not ready after {}s: {}",
                timeout_secs,
                result.detail
            );
        }

        tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;
    }
}
