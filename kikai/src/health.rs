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
///
/// Excludes pods in Pending state that are less than 60 seconds old (transient startup)
/// and pods in Terminating state (graceful shutdown in progress).
pub async fn check_pods(cluster: &str) -> HealthResult {
    // Get non-Running/Succeeded pods with their phase, creation timestamp, and deletion timestamp
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
            "jsonpath={range .items[*]}{.metadata.name} {.status.phase} {.metadata.creationTimestamp} {.metadata.deletionTimestamp}{\"\\n\"}{end}",
        ])
        .output()
        .await;

    match output {
        Ok(out) if out.status.success() => {
            let raw = String::from_utf8_lossy(&out.stdout).trim().to_string();
            if raw.is_empty() {
                return HealthResult {
                    healthy: true,
                    detail: "All pods running or completed".to_string(),
                };
            }

            let now = std::time::SystemTime::now();
            let mut unhealthy_names = Vec::new();

            for line in raw.lines() {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.is_empty() {
                    continue;
                }

                let name = parts[0];
                let phase = parts.get(1).copied().unwrap_or("");
                let created = parts.get(2).copied().unwrap_or("");
                let deletion_ts = parts.get(3).copied().unwrap_or("");

                // Skip pods being terminated (deletionTimestamp is set)
                if !deletion_ts.is_empty() {
                    continue;
                }

                // Skip Pending pods younger than 60 seconds
                if phase == "Pending" {
                    if let Ok(age) = pod_age_secs(created, now) {
                        if age < 60 {
                            continue;
                        }
                    }
                }

                unhealthy_names.push(name.to_string());
            }

            if unhealthy_names.is_empty() {
                HealthResult {
                    healthy: true,
                    detail: "All pods running or completed".to_string(),
                }
            } else {
                let count = unhealthy_names.len();
                let names = unhealthy_names.join(" ");
                HealthResult {
                    healthy: false,
                    detail: format!("{count} unhealthy pod(s): {names}"),
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

/// Parse a RFC 3339 timestamp and return the age in seconds relative to `now`.
/// Returns an error if parsing fails.
fn pod_age_secs(timestamp: &str, now: std::time::SystemTime) -> Result<u64> {
    // Kubernetes timestamps look like: 2024-01-15T10:30:00Z
    // Parse manually to avoid pulling in chrono as a dependency.
    // Format: YYYY-MM-DDTHH:MM:SSZ
    let ts = timestamp.trim_end_matches('Z');
    let parts: Vec<&str> = ts.split('T').collect();
    if parts.len() != 2 {
        anyhow::bail!("invalid timestamp: {timestamp}");
    }

    let date_parts: Vec<u64> = parts[0]
        .split('-')
        .filter_map(|s| s.parse().ok())
        .collect();
    let time_parts: Vec<u64> = parts[1]
        .split(':')
        .filter_map(|s| s.parse().ok())
        .collect();

    if date_parts.len() != 3 || time_parts.len() != 3 {
        anyhow::bail!("invalid timestamp: {timestamp}");
    }

    // Approximate: convert to days since epoch then to seconds.
    // This is good enough for a 60-second threshold comparison.
    let (year, month, day) = (date_parts[0], date_parts[1], date_parts[2]);
    let (hour, min, sec) = (time_parts[0], time_parts[1], time_parts[2]);

    // Days from year (approximate, accounting for leap years)
    let mut days: u64 = 0;
    for y in 1970..year {
        days += if y % 4 == 0 && (y % 100 != 0 || y % 400 == 0) {
            366
        } else {
            365
        };
    }
    let is_leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
    let month_days = [
        0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31,
    ];
    for m in 1..month {
        days += month_days[m as usize];
        if m == 2 && is_leap {
            days += 1;
        }
    }
    days += day - 1;

    let ts_secs = days * 86400 + hour * 3600 + min * 60 + sec;
    let now_secs = now
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();

    Ok(now_secs.saturating_sub(ts_secs))
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
/// Uses exponential backoff starting at 2s, maxing at 10s.
pub async fn wait_for_api(api_port: u16, timeout_secs: u64) -> Result<()> {
    info!(port = api_port, timeout = timeout_secs, "waiting for API server");
    let deadline =
        tokio::time::Instant::now() + tokio::time::Duration::from_secs(timeout_secs);
    let mut interval_secs: u64 = 2;

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

        tokio::time::sleep(tokio::time::Duration::from_secs(interval_secs)).await;
        interval_secs = (interval_secs * 2).min(10);
    }
}

/// Poll until the cluster node is Ready, with the given timeout in seconds.
/// Uses exponential backoff starting at 2s, maxing at 10s.
pub async fn wait_for_node_ready(cluster: &str, timeout_secs: u64) -> Result<()> {
    info!(cluster = %cluster, timeout = timeout_secs, "waiting for node to be ready");
    let deadline =
        tokio::time::Instant::now() + tokio::time::Duration::from_secs(timeout_secs);
    let mut interval_secs: u64 = 2;

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

        tokio::time::sleep(tokio::time::Duration::from_secs(interval_secs)).await;
        interval_secs = (interval_secs * 2).min(10);
    }
}

/// Poll until all FluxCD kustomizations are Ready, with the given timeout in seconds.
/// Uses exponential backoff starting at 2s, maxing at 10s.
pub async fn wait_for_flux(cluster: &str, timeout_secs: u64) -> Result<()> {
    info!(cluster = %cluster, timeout = timeout_secs, "waiting for flux kustomizations");
    let deadline =
        tokio::time::Instant::now() + tokio::time::Duration::from_secs(timeout_secs);
    let mut interval_secs: u64 = 2;

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

        tokio::time::sleep(tokio::time::Duration::from_secs(interval_secs)).await;
        interval_secs = (interval_secs * 2).min(10);
    }
}
