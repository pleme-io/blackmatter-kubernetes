use anyhow::{Context, Result};
use tracing::info;

/// Check whether cluster secrets already exist in SOPS.
/// Returns true if the server-token for the given cluster is present.
pub async fn check_existing(cluster: &str, secrets_file: &str) -> Result<bool> {
    let output = tokio::process::Command::new("sops")
        .args([
            "-d",
            "--extract",
            &format!("[\"clusters\"][\"{cluster}\"][\"server-token\"]"),
            secrets_file,
        ])
        .output()
        .await
        .context("checking existing secrets")?;

    if output.status.success() {
        let token = String::from_utf8_lossy(&output.stdout);
        let token_preview = if token.len() > 20 {
            &token[..20]
        } else {
            &token
        };
        println!("Cluster '{cluster}' already initialized.");
        println!("  Server token: {token_preview}...");
        println!("  Age key:      present");
        println!();
        println!("To re-initialize, remove the entries first with sops.");
        Ok(true)
    } else {
        Ok(false)
    }
}

/// Set a value in a SOPS-encrypted file at the given key path.
pub async fn set(secrets_file: &str, key_path: &str, value: &str) -> Result<()> {
    let status = tokio::process::Command::new("sops")
        .args(["set", secrets_file, key_path, &format!("\"{value}\"")])
        .status()
        .await
        .with_context(|| format!("sops set {key_path}"))?;

    if !status.success() {
        anyhow::bail!("sops set failed for {key_path}");
    }
    Ok(())
}

/// Extract a value from a SOPS-encrypted file at the given key path.
pub async fn extract(secrets_file: &str, key_path: &str) -> Result<String> {
    let output = tokio::process::Command::new("sops")
        .args(["-d", "--extract", key_path, secrets_file])
        .output()
        .await
        .with_context(|| format!("sops extract {key_path}"))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        anyhow::bail!("sops extract failed for {key_path}: {stderr}");
    }

    Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

/// Update .sops.yaml to include the given age public key in the first creation rule.
pub async fn update_sops_yaml(sops_yaml: &str, age_public: &str) -> Result<()> {
    let output = tokio::process::Command::new("yq")
        .args([".creation_rules[0].age", sops_yaml])
        .output()
        .await
        .context("reading .sops.yaml")?;

    let current = String::from_utf8_lossy(&output.stdout).trim().to_string();
    if current.contains(age_public) {
        info!("age public key already in .sops.yaml");
        return Ok(());
    }

    let new_age = format!("{current},{age_public}");
    let status = tokio::process::Command::new("yq")
        .args([
            "-i",
            &format!(".creation_rules[0].age = \"{new_age}\""),
            sops_yaml,
        ])
        .status()
        .await
        .context("updating .sops.yaml")?;

    if !status.success() {
        anyhow::bail!("yq update failed");
    }
    info!("added VM age public key to .sops.yaml");
    Ok(())
}

/// Re-encrypt a SOPS file with all configured recipients.
pub async fn updatekeys(secrets_file: &str) -> Result<()> {
    let status = tokio::process::Command::new("sops")
        .args(["updatekeys", "-y", secrets_file])
        .status()
        .await
        .context("running sops updatekeys")?;

    if !status.success() {
        anyhow::bail!("sops updatekeys failed");
    }
    info!("re-encrypted secrets with all recipients");
    Ok(())
}
