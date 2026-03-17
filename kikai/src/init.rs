use anyhow::{Context, Result};
use std::process::ExitCode;
use tracing::info;

use crate::config::ClusterConfig;
use crate::sops;

/// Extract the darwin host name from a cluster name.
/// Convention: "ryn-k3s" -> "ryn", "prod-server" -> "prod"
pub fn host_from_cluster(cluster: &str) -> &str {
    cluster.split('-').next().unwrap_or(cluster)
}

/// Initialize cluster bootstrap secrets: age keypair, k3s server token, admin password.
///
/// Stores them in SOPS and updates .sops.yaml with the VM's age public key.
/// Idempotent: if secrets already exist, displays them and exits successfully.
///
/// When all three `KIKAI_*_FILE` env vars are set and their target files exist,
/// secret generation is skipped entirely — secrets are already provisioned via the
/// environment.
pub async fn run(config: &ClusterConfig, dry_run: bool) -> Result<ExitCode> {
    // If all secrets are provided via environment, skip init entirely
    if !dry_run && sops::all_secrets_from_env() {
        info!(cluster = %config.name, "secrets already provisioned via environment, skipping init");
        println!("Cluster '{}': secrets already provisioned via environment.", config.name);
        return Ok(ExitCode::SUCCESS);
    }

    // Check idempotency: if secrets already exist, show them and exit
    if !dry_run && sops::check_existing(&config.name, &config.secrets_file).await? {
        return Ok(ExitCode::SUCCESS);
    }

    info!(cluster = %config.name, "initializing cluster secrets");

    // 1. Generate age keypair
    let (age_public, age_private) = generate_age_keypair().await?;
    info!(public_key = %age_public, "generated age keypair");

    // 2. Generate k3s server token
    let server_token = generate_random_hex(48).await?;
    info!(token_prefix = %&server_token[..16], "generated server token");

    // 3. Generate admin password for kubeconfig
    let admin_password = generate_random_hex(32).await?;
    info!(pass_prefix = %&admin_password[..16], "generated admin password");

    if dry_run {
        println!();
        println!("Cluster: {}", config.name);
        println!("  Age public key:   {age_public}");
        println!("  Server token:     {}...", &server_token[..16]);
        println!("  Admin password:   {}...", &admin_password[..16]);
        println!();
        println!("[dry-run] Would store in SOPS and update .sops.yaml");
        return Ok(ExitCode::SUCCESS);
    }

    // 4. Store secrets in SOPS
    sops::set(
        &config.secrets_file,
        &format!(
            "[\"clusters\"][\"{}\"][\"server-token\"]",
            config.name
        ),
        &server_token,
    )
    .await?;
    sops::set(
        &config.secrets_file,
        &format!("[\"clusters\"][\"{}\"][\"age-key\"]", config.name),
        &age_private,
    )
    .await?;
    sops::set(
        &config.secrets_file,
        &format!(
            "[\"clusters\"][\"{}\"][\"admin-password\"]",
            config.name
        ),
        &admin_password,
    )
    .await?;

    // 5. Also store as kubeconfig token (referenced by darwin kubeconfig template)
    // Convention: ryn/kubernetes/<cluster>/token
    let host = host_from_cluster(&config.name);
    sops::set(
        &config.secrets_file,
        &format!(
            "[\"{host}\"][\"kubernetes\"][\"{}\"][\"token\"]",
            config.name
        ),
        &admin_password,
    )
    .await?;
    info!("stored all secrets in SOPS");

    // 6. Update .sops.yaml with VM's age public key
    sops::update_sops_yaml(&config.sops_yaml, &age_public).await?;

    // 7. Re-encrypt with all recipients
    sops::updatekeys(&config.secrets_file).await?;

    println!();
    println!("Cluster '{}' initialized successfully.", config.name);
    println!();
    println!("Secrets stored:");
    println!(
        "  clusters/{}/server-token    -- k3s server bootstrap token",
        config.name
    );
    println!(
        "  clusters/{}/age-key         -- VM SOPS age private key",
        config.name
    );
    println!(
        "  clusters/{}/admin-password  -- k3s admin kubeconfig password",
        config.name
    );
    println!(
        "  {host}/kubernetes/{}/token  -- kubeconfig user token",
        config.name
    );
    println!();
    println!("Next steps:");
    println!("  1. git add .sops.yaml secrets.yaml && git commit");
    println!(
        "  2. nix build .#packages.aarch64-linux.{}-image",
        config.name
    );
    println!("  3. kikai up --cluster {}", config.name);

    Ok(ExitCode::SUCCESS)
}

/// Generate an age keypair, returning (public_key, private_key).
///
/// age-keygen outputs:
///   stderr: "Public key: age1xxx..." (capital P)
///   stdout: "# created: ...\n# public key: age1xxx...\nAGE-SECRET-KEY-xxx..."
async fn generate_age_keypair() -> Result<(String, String)> {
    let output = tokio::process::Command::new("age-keygen")
        .output()
        .await
        .context("running age-keygen")?;

    if !output.status.success() {
        anyhow::bail!(
            "age-keygen failed: {}",
            String::from_utf8_lossy(&output.stderr)
        );
    }

    let stderr = String::from_utf8_lossy(&output.stderr);
    let stdout = String::from_utf8_lossy(&output.stdout);

    // Try stderr first (has "Public key:" with capital P), then stdout
    // (has "# public key:" with lowercase p). Use case-insensitive matching.
    let public = stderr
        .lines()
        .chain(stdout.lines())
        .find(|l| l.to_lowercase().contains("public key:"))
        .and_then(|l| {
            // Handle both "Public key: age1..." and "# public key: age1..."
            l.split("key: ").nth(1).or_else(|| l.split("key:").nth(1))
        })
        .ok_or_else(|| anyhow::anyhow!("could not parse age public key"))?
        .trim()
        .to_string();

    let private = stdout
        .lines()
        .find(|l| l.starts_with("AGE-SECRET-KEY-"))
        .ok_or_else(|| anyhow::anyhow!("could not parse age private key"))?
        .trim()
        .to_string();

    Ok((public, private))
}

/// Generate a random hex string of the given byte count using openssl.
async fn generate_random_hex(bytes: usize) -> Result<String> {
    let output = tokio::process::Command::new("openssl")
        .args(["rand", "-hex", &bytes.to_string()])
        .output()
        .await
        .context("running openssl rand")?;

    if !output.status.success() {
        anyhow::bail!(
            "openssl rand failed: {}",
            String::from_utf8_lossy(&output.stderr)
        );
    }

    Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_host_from_cluster() {
        assert_eq!(host_from_cluster("ryn-k3s"), "ryn");
        assert_eq!(host_from_cluster("prod-server"), "prod");
        assert_eq!(host_from_cluster("standalone"), "standalone");
    }

    #[test]
    fn test_host_from_cluster_edge_cases() {
        assert_eq!(host_from_cluster(""), "");
        assert_eq!(host_from_cluster("a-b-c-d"), "a");
        assert_eq!(host_from_cluster("-leading"), "");
    }
}
