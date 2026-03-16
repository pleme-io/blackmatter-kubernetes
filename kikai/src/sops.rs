use anyhow::{Context, Result};
use tracing::{info, warn};

/// Try to read a secret from a pre-decrypted file referenced by an env var.
///
/// Returns `None` if the env var is not set or the file doesn't exist.
/// The env var value is a file path; the file contents are trimmed and returned.
fn try_read_decrypted(env_var: &str) -> Option<String> {
    let path = std::env::var(env_var).ok()?;
    let path = std::path::Path::new(&path);
    if path.exists() {
        // Security: warn if file is world-readable (mode > 0o600)
        #[cfg(unix)]
        {
            use std::os::unix::fs::MetadataExt;
            if let Ok(meta) = path.metadata() {
                let mode = meta.mode() & 0o777;
                if mode & 0o077 != 0 {
                    warn!(
                        path = %path.display(),
                        mode = format!("{mode:04o}"),
                        "secret file has overly permissive permissions (should be 0600 or stricter)"
                    );
                }
            }
        }
        std::fs::read_to_string(path).ok().map(|s| s.trim().to_string())
    } else {
        None
    }
}

/// Map a SOPS key path to a `KIKAI_*_FILE` env var name.
///
/// Extracts the last bracketed component, uppercases it, replaces hyphens with
/// underscores, and wraps it as `KIKAI_{NAME}_FILE`.
///
/// Example: `["clusters"]["ryn-k3s"]["server-token"]` -> `KIKAI_SERVER_TOKEN_FILE`
fn key_path_to_env_var(key_path: &str) -> String {
    // Extract the last ["..."] component
    let last = key_path
        .rsplit("[\"")
        .next()
        .and_then(|s| s.strip_suffix("\"]"))
        .unwrap_or(key_path);

    let name = last.to_uppercase().replace('-', "_");
    format!("KIKAI_{name}_FILE")
}

/// Check whether all three core cluster secrets are available via env vars.
///
/// Returns `true` if `KIKAI_SERVER_TOKEN_FILE`, `KIKAI_AGE_KEY_FILE`, and
/// `KIKAI_ADMIN_PASSWORD_FILE` are all set and their target files exist.
pub fn all_secrets_from_env() -> bool {
    const VARS: &[&str] = &[
        "KIKAI_SERVER_TOKEN_FILE",
        "KIKAI_AGE_KEY_FILE",
        "KIKAI_ADMIN_PASSWORD_FILE",
    ];
    VARS.iter().all(|v| try_read_decrypted(v).is_some())
}

/// Check whether cluster secrets already exist in SOPS (or via env vars).
/// Returns true if the server-token for the given cluster is present.
pub async fn check_existing(cluster: &str, secrets_file: &str) -> Result<bool> {
    // Check env var path first
    let key_path = format!("[\"clusters\"][\"{cluster}\"][\"server-token\"]");
    let env_key = key_path_to_env_var(&key_path);
    if let Some(token) = try_read_decrypted(&env_key) {
        let token_preview = if token.len() > 20 {
            &token[..20]
        } else {
            &token
        };
        println!("Cluster '{cluster}' already initialized (via environment).");
        println!("  Server token: {token_preview}...");
        println!("  Age key:      present");
        println!();
        println!("To re-initialize, remove the entries first with sops.");
        return Ok(true);
    }

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
    if !std::path::Path::new(secrets_file).exists() {
        anyhow::bail!("secrets file does not exist: {secrets_file}");
    }

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
///
/// If a matching `KIKAI_*_FILE` environment variable is set and the referenced
/// file exists, the value is read directly from that file — bypassing sops
/// entirely. This lets callers pre-decrypt secrets and inject them via the
/// environment, eliminating sops as a runtime dependency.
pub async fn extract(secrets_file: &str, key_path: &str) -> Result<String> {
    // Check for pre-decrypted file via env var
    let env_key = key_path_to_env_var(key_path);
    if let Some(value) = try_read_decrypted(&env_key) {
        info!(env_var = %env_key, "read secret from pre-decrypted file");
        return Ok(value);
    }

    // Fall back to sops
    if !std::path::Path::new(secrets_file).exists() {
        anyhow::bail!("secrets file does not exist: {secrets_file}");
    }

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

/// Remove a key from a SOPS-encrypted file using `sops unset`.
pub async fn remove(secrets_file: &str, key_path: &str) -> Result<()> {
    if !std::path::Path::new(secrets_file).exists() {
        anyhow::bail!("secrets file does not exist: {secrets_file}");
    }

    let status = tokio::process::Command::new("sops")
        .args(["unset", secrets_file, key_path])
        .status()
        .await
        .with_context(|| format!("sops unset {key_path}"))?;

    if !status.success() {
        anyhow::bail!("sops unset failed for {key_path}");
    }
    info!("removed {key_path} from {secrets_file}");
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sops_key_path_format() {
        let cluster = "ryn-k3s";
        let server_token_path = format!("[\"clusters\"][\"{cluster}\"][\"server-token\"]");
        assert_eq!(
            server_token_path,
            "[\"clusters\"][\"ryn-k3s\"][\"server-token\"]"
        );

        let age_key_path = format!("[\"clusters\"][\"{cluster}\"][\"age-key\"]");
        assert_eq!(age_key_path, "[\"clusters\"][\"ryn-k3s\"][\"age-key\"]");
    }

    #[test]
    fn test_key_path_to_env_var() {
        assert_eq!(
            key_path_to_env_var("[\"clusters\"][\"ryn-k3s\"][\"server-token\"]"),
            "KIKAI_SERVER_TOKEN_FILE"
        );
        assert_eq!(
            key_path_to_env_var("[\"clusters\"][\"ryn-k3s\"][\"age-key\"]"),
            "KIKAI_AGE_KEY_FILE"
        );
        assert_eq!(
            key_path_to_env_var("[\"clusters\"][\"ryn-k3s\"][\"admin-password\"]"),
            "KIKAI_ADMIN_PASSWORD_FILE"
        );
    }

    #[test]
    fn test_try_read_decrypted_missing_env() {
        // Env var not set → None
        assert!(try_read_decrypted("KIKAI_NONEXISTENT_TEST_FILE").is_none());
    }

    #[test]
    fn test_try_read_decrypted_file_exists() {
        let tmp = tempfile::NamedTempFile::new().unwrap();
        std::fs::write(tmp.path(), "  my-secret-value\n").unwrap();
        std::env::set_var(
            "KIKAI_TEST_SECRET_FILE",
            tmp.path().to_str().unwrap(),
        );
        let result = try_read_decrypted("KIKAI_TEST_SECRET_FILE");
        std::env::remove_var("KIKAI_TEST_SECRET_FILE");
        assert_eq!(result, Some("my-secret-value".to_string()));
    }

    #[test]
    fn test_try_read_decrypted_file_missing() {
        std::env::set_var(
            "KIKAI_TEST_MISSING_FILE",
            "/tmp/kikai-nonexistent-test-file",
        );
        let result = try_read_decrypted("KIKAI_TEST_MISSING_FILE");
        std::env::remove_var("KIKAI_TEST_MISSING_FILE");
        assert!(result.is_none());
    }
}
