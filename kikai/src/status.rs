use anyhow::Result;
use std::process::ExitCode;

use crate::config::ClusterConfig;
use crate::health;

/// Display cluster health status as a table or JSON.
pub async fn run(config: &ClusterConfig, json_output: bool) -> Result<ExitCode> {
    let summary = health::check_all(&config.name, config.api_port).await;

    if json_output {
        let json = serde_json::to_string_pretty(&summary)?;
        println!("{json}");
    } else {
        println!("Cluster: {}", config.name);
        println!();
        print_row("VM", summary.vm_running, if summary.vm_running { "running" } else { "stopped" });
        print_row("API", summary.api.healthy, &summary.api.detail);
        print_row("Node", summary.node.healthy, &summary.node.detail);
        print_row("Flux", summary.flux.healthy, &summary.flux.detail);
        print_row("Pods", summary.pods.healthy, &summary.pods.detail);
    }

    let all_healthy = summary.vm_running
        && summary.api.healthy
        && summary.node.healthy
        && summary.flux.healthy
        && summary.pods.healthy;

    if all_healthy {
        Ok(ExitCode::SUCCESS)
    } else {
        Ok(ExitCode::FAILURE)
    }
}

fn print_row(label: &str, healthy: bool, detail: &str) {
    let icon = if healthy { "[OK]" } else { "[!!]" };
    println!("  {icon} {label:<6} {detail}");
}
