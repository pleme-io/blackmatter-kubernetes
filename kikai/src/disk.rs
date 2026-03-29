use anyhow::{Context, Result};
use std::path::{Path, PathBuf};
use tracing::info;

use crate::sops;

/// Boot files extracted from a root disk image.
pub struct BootFiles {
    /// Path to the kernel (bzImage or Image)
    pub kernel: PathBuf,
    /// Path to the initrd
    pub initrd: PathBuf,
    /// Init path inside the VM (e.g., /nix/store/.../init)
    pub init: String,
    /// Temp directory that must be kept alive while boot files are in use
    _tmp_dir: PathBuf,
}

/// Build and locate the root disk image from a nix flake.
pub async fn locate_root_disk(cluster: &str, nix_flake: &str) -> Result<PathBuf> {
    let output = tokio::process::Command::new("nix")
        .args([
            "build",
            &format!("{nix_flake}#packages.aarch64-linux.{cluster}-image"),
            "--no-link",
            "--print-out-paths",
        ])
        .output()
        .await
        .context("building root disk image")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        anyhow::bail!("nix build failed: {stderr}");
    }

    let store_path = String::from_utf8_lossy(&output.stdout).trim().to_string();
    let img_path = PathBuf::from(&store_path).join("nixos.img");
    if !img_path.exists() {
        anyhow::bail!("root disk not found at {}", img_path.display());
    }
    info!(path = %img_path.display(), "located root disk image");
    Ok(img_path)
}

/// Create a sparse disk image of the given size using dd.
pub async fn create_sparse_disk(path: &Path, size: &str) -> Result<()> {
    let status = tokio::process::Command::new("dd")
        .args([
            "if=/dev/zero",
            &format!("of={}", path.display()),
            "bs=1",
            "count=0",
            &format!("seek={size}"),
        ])
        .stderr(std::process::Stdio::null())
        .status()
        .await
        .context("creating sparse disk")?;

    if !status.success() {
        anyhow::bail!("dd failed creating sparse disk");
    }
    info!(path = %path.display(), size = %size, "created sparse disk");
    Ok(())
}

/// Create a seed disk (FAT12 image) provisioned with cluster secrets from SOPS.
pub async fn create_seed_disk(
    seed_path: &Path,
    cluster: &str,
    secrets_file: &str,
) -> Result<()> {
    // Create 2MB FAT image
    let status = tokio::process::Command::new("dd")
        .args([
            "if=/dev/zero",
            &format!("of={}", seed_path.display()),
            "bs=1M",
            "count=2",
        ])
        .stderr(std::process::Stdio::null())
        .status()
        .await
        .context("creating seed disk")?;
    if !status.success() {
        anyhow::bail!("dd failed creating seed disk");
    }

    // Format as FAT12
    let status = tokio::process::Command::new("newfs_msdos")
        .args(["-F", "12", &seed_path.display().to_string()])
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()
        .await
        .context("formatting seed disk as FAT")?;
    if !status.success() {
        anyhow::bail!("newfs_msdos failed");
    }

    // Mount seed disk
    let mount_dir = tempfile::tempdir().context("creating temp mount dir")?;
    let mount_path = mount_dir.path();

    let status = tokio::process::Command::new("hdiutil")
        .args([
            "attach",
            "-mountpoint",
            &mount_path.display().to_string(),
            &seed_path.display().to_string(),
            "-nobrowse",
        ])
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()
        .await
        .context("mounting seed disk")?;
    if !status.success() {
        anyhow::bail!("hdiutil attach failed for seed disk");
    }

    // Write age key
    let age_key = sops::extract(
        secrets_file,
        &format!("[\"clusters\"][\"{cluster}\"][\"age-key\"]"),
    )
    .await?;
    std::fs::write(mount_path.join("age-key.txt"), &age_key).context("writing age key")?;

    // Write k3s admin password (passwd format)
    let admin_pass = sops::extract(
        secrets_file,
        &format!("[\"clusters\"][\"{cluster}\"][\"admin-password\"]"),
    )
    .await?;
    let passwd_line = format!("{admin_pass},admin,admin,system:masters\n");
    std::fs::write(mount_path.join("k3s-passwd"), &passwd_line)
        .context("writing k3s passwd")?;

    // Write server token
    let server_token = sops::extract(
        secrets_file,
        &format!("[\"clusters\"][\"{cluster}\"][\"server-token\"]"),
    )
    .await?;
    std::fs::write(mount_path.join("server-token"), &server_token)
        .context("writing server token")?;

    // Unmount
    let _ = tokio::process::Command::new("hdiutil")
        .args(["detach", &mount_path.display().to_string()])
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()
        .await;

    info!("seed disk provisioned");
    Ok(())
}

/// Extract kernel, initrd, and init path from a NixOS root disk image.
pub async fn extract_boot_files(root_disk: &Path) -> Result<BootFiles> {
    let tmp_dir = tempfile::tempdir().context("creating temp dir")?;
    let mount_point = tmp_dir.path().join("mnt");
    std::fs::create_dir_all(&mount_point).context("creating mount point")?;

    // Mount root image read-only
    let status = tokio::process::Command::new("hdiutil")
        .args([
            "attach",
            "-mountpoint",
            &mount_point.display().to_string(),
            "-readonly",
            &root_disk.display().to_string(),
            "-nobrowse",
        ])
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()
        .await
        .context("mounting root disk")?;
    if !status.success() {
        anyhow::bail!("hdiutil attach failed for root disk");
    }

    let nix_store = mount_point.join("nix/store");

    // Find kernel
    let kernel = find_file(&nix_store, &["bzImage", "Image"])?;
    // Find initrd
    let initrd = find_file(&nix_store, &["initrd"])?;
    // Find init
    let init = find_init(&nix_store)?;

    // Copy kernel and initrd to persistent temp files
    let kernel_out = tmp_dir.path().join("kernel");
    let initrd_out = tmp_dir.path().join("initrd");
    std::fs::copy(&kernel, &kernel_out).context("copying kernel")?;
    std::fs::copy(&initrd, &initrd_out).context("copying initrd")?;

    // Unmount
    let _ = tokio::process::Command::new("hdiutil")
        .args(["detach", &mount_point.display().to_string()])
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()
        .await;

    // Keep the temp dir so files persist until process exits
    #[allow(deprecated)]
    let tmp_path = tmp_dir.into_path();

    info!(
        kernel = %tmp_path.join("kernel").display(),
        initrd = %tmp_path.join("initrd").display(),
        init = %init,
        "extracted boot files"
    );

    Ok(BootFiles {
        kernel: tmp_path.join("kernel"),
        initrd: tmp_path.join("initrd"),
        init,
        _tmp_dir: tmp_path,
    })
}

/// Create a writable copy of the root disk image.
pub async fn create_root_copy(root_disk: &Path, root_copy: &Path) -> Result<()> {
    std::fs::copy(root_disk, root_copy)
        .with_context(|| {
            format!(
                "copying {} to {}",
                root_disk.display(),
                root_copy.display()
            )
        })?;
    info!(path = %root_copy.display(), "created writable root disk copy");
    Ok(())
}

fn find_file(nix_store: &Path, names: &[&str]) -> Result<PathBuf> {
    for entry in std::fs::read_dir(nix_store).context("reading nix store")? {
        let entry = entry?;
        if entry.file_type()?.is_dir() {
            for name in names {
                let candidate = entry.path().join(name);
                if candidate.exists() {
                    return Ok(candidate);
                }
            }
        }
    }
    anyhow::bail!(
        "could not find {} in nix store",
        names.join(" or ")
    )
}

fn find_init(nix_store: &Path) -> Result<String> {
    for entry in std::fs::read_dir(nix_store).context("reading nix store")? {
        let entry = entry?;
        let name = entry.file_name().to_string_lossy().to_string();
        if name.contains("nixos-system-") && entry.file_type()?.is_dir() {
            let init = entry.path().join("init");
            if init.exists() {
                return Ok(init.display().to_string());
            }
        }
    }
    anyhow::bail!("could not find nixos-system init in nix store")
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    #[test]
    fn test_find_file_kernel() {
        let tmp = TempDir::new().unwrap();
        let store_dir = tmp.path().join("abc123-linux-kernel");
        fs::create_dir_all(&store_dir).unwrap();
        fs::write(store_dir.join("Image"), b"fake kernel").unwrap();

        let result = find_file(tmp.path(), &["bzImage", "Image"]);
        assert!(result.is_ok());
        assert!(result.unwrap().ends_with("Image"));
    }

    #[test]
    fn test_find_file_not_found() {
        let tmp = TempDir::new().unwrap();
        let result = find_file(tmp.path(), &["bzImage", "Image"]);
        assert!(result.is_err());
    }

    #[test]
    fn test_find_init() {
        let tmp = TempDir::new().unwrap();
        let sys_dir = tmp.path().join("abc123-nixos-system-ryn-k3s-24.11");
        fs::create_dir_all(&sys_dir).unwrap();
        fs::write(sys_dir.join("init"), b"#!/nix/store/...").unwrap();

        let result = find_init(tmp.path());
        assert!(result.is_ok());
        assert!(result.unwrap().contains("init"));
    }

    #[test]
    fn test_find_init_not_found() {
        let tmp = TempDir::new().unwrap();
        let result = find_init(tmp.path());
        assert!(result.is_err());
    }
}
