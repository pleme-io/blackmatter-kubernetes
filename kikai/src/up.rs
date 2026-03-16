use anyhow::{Context, Result};
use std::process::ExitCode;
use tracing::info;

use crate::config::{self, ClusterConfig};
use crate::{disk, health, init, sops, vm};

/// Bring up a k3s cluster: check init, build image, create disks, launch VM, wait for health.
pub async fn run(config: &ClusterConfig, no_seed: bool, no_wait: bool) -> Result<ExitCode> {
    // Check if VM is already running
    if vm::is_running(&config.name)? {
        let pid = vm::read_pid(&config.name)?;
        info!(
            cluster = %config.name,
            pid = ?pid,
            "VM is already running"
        );
        println!("Cluster '{}' is already running (PID {:?}).", config.name, pid);
        return Ok(ExitCode::SUCCESS);
    }

    let data_dir = config::data_dir(&config.name)?;
    let data_disk = data_dir.join("data.raw");
    let seed_disk = data_dir.join("seed.img");
    let root_copy = data_dir.join("root.raw");

    // 1. Check if cluster has been initialized (secrets exist)
    info!(cluster = %config.name, "checking cluster initialization");
    let initialized =
        sops::check_existing(&config.name, &config.secrets_file).await?;
    if !initialized {
        info!("cluster not initialized, running init");
        let code = init::run(config, false).await?;
        if code != ExitCode::SUCCESS {
            return Ok(code);
        }
    }

    // 2. Build/locate root disk image
    info!(cluster = %config.name, "locating root disk image");
    let root_disk = disk::locate_root_disk(&config.name, &config.nix_flake).await?;

    // 3. Create data directory
    std::fs::create_dir_all(&data_dir)
        .with_context(|| format!("creating {}", data_dir.display()))?;

    // 4. Create data disk if needed
    if !data_disk.exists() {
        info!(size = %config.disk_size, "creating sparse data disk");
        disk::create_sparse_disk(&data_disk, &config.disk_size).await?;
    }

    // 5. Create seed disk with secrets
    if !no_seed {
        info!("provisioning seed disk with cluster secrets");
        disk::create_seed_disk(&seed_disk, &config.name, &config.secrets_file).await?;
    }

    // 6. Extract kernel, initrd, init from root image
    info!("extracting kernel and initrd from image");
    let boot_files = disk::extract_boot_files(&root_disk).await?;

    // 7. Create writable root copy
    info!("creating writable root disk copy");
    disk::create_root_copy(&root_disk, &root_copy).await?;

    // 8. Launch VM
    println!();
    println!("Starting {} VM...", config.name);
    println!("  Root: {} (vda)", root_copy.display());
    println!("  Data: {} (vdb)", data_disk.display());
    println!("  Seed: {} (vdc)", seed_disk.display());
    println!("  K8s API: localhost:{}", config.api_port);
    println!("  SSH: localhost:{}", config.ssh_port);
    println!();

    let pid = vm::launch(config, &boot_files).await?;
    info!(pid = pid, "VM launched");
    println!("VM launched with PID {pid}.");

    // 9. Wait for health (unless --no-wait)
    if !no_wait {
        let timeout = 300; // 5 minutes

        println!("Waiting for cluster to become healthy (timeout: {timeout}s)...");

        info!("waiting for API server");
        health::wait_for_api(config.api_port, timeout).await?;
        println!("  API server: healthy");

        info!("waiting for node to be ready");
        health::wait_for_node_ready(&config.name, timeout).await?;
        println!("  Node: ready");

        info!("waiting for flux kustomizations");
        health::wait_for_flux(&config.name, timeout).await?;
        println!("  Flux: ready");

        println!();
        println!("Cluster '{}' is up and healthy.", config.name);
    } else {
        println!();
        println!(
            "Cluster '{}' VM launched. Use 'kikai status' to check health.",
            config.name
        );
    }

    Ok(ExitCode::SUCCESS)
}
