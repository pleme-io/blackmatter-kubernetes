use anyhow::{Context, Result};
use tracing::info;

use crate::config::{self, ClusterConfig};
use crate::disk::BootFiles;

/// Launch a vfkit VM as a background process and return its PID.
///
/// The VM is spawned detached (stdout/stderr piped to null) so the parent
/// process is free to exit or continue monitoring.
pub async fn launch(cfg: &ClusterConfig, boot_files: &BootFiles) -> Result<u32> {
    let data_dir = config::data_dir(&cfg.name)?;
    let data_disk = data_dir.join("data.raw");
    let seed_disk = data_dir.join("seed.img");
    let root_copy = data_dir.join("root.raw");

    let net_config = format!(
        "nat,localPort={}:guestPort=6443,localPort={}:guestPort=22",
        cfg.api_port, cfg.ssh_port
    );

    let child = tokio::process::Command::new("vfkit")
        .args([
            "--cpus",
            &cfg.cpus.to_string(),
            "--memory",
            &cfg.memory.to_string(),
            "--bootloader",
            &format!(
                "linux,kernel={},initrd={},cmdline=console=hvc0 root=/dev/vda init={}",
                boot_files.kernel.display(),
                boot_files.initrd.display(),
                boot_files.init
            ),
            "--device",
            &format!("virtio-blk,path={}", root_copy.display()),
            "--device",
            &format!("virtio-blk,path={}", data_disk.display()),
            "--device",
            &format!("virtio-blk,path={}", seed_disk.display()),
            "--device",
            &format!("virtio-net,{net_config}"),
            "--device",
            "virtio-serial,stdio",
        ])
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .stdin(std::process::Stdio::null())
        .spawn()
        .context("spawning vfkit")?;

    let pid = child
        .id()
        .ok_or_else(|| anyhow::anyhow!("failed to get vfkit PID"))?;

    // Write PID file
    let pid_file = config::pid_file(&cfg.name)?;
    std::fs::write(&pid_file, pid.to_string())
        .with_context(|| format!("writing PID file {}", pid_file.display()))?;

    info!(pid = pid, cluster = %cfg.name, "launched vfkit VM");
    Ok(pid)
}

/// Check whether the VM for the given cluster is currently running.
///
/// Reads the PID file and checks if a process with that PID exists.
pub fn is_running(cluster: &str) -> Result<bool> {
    let pid_file = config::pid_file(cluster)?;
    if !pid_file.exists() {
        return Ok(false);
    }

    let pid_str = std::fs::read_to_string(&pid_file).context("reading PID file")?;
    let pid: i32 = pid_str.trim().parse().context("parsing PID")?;

    // Check if process exists with kill -0
    Ok(libc_kill(pid))
}

/// Send signal 0 to check if a process exists.
fn libc_kill(pid: i32) -> bool {
    // Use std::process::Command to check via kill -0
    std::process::Command::new("kill")
        .args(["-0", &pid.to_string()])
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

/// Stop the VM gracefully via SSH shutdown, waiting for the process to exit.
pub async fn stop(cfg: &ClusterConfig, timeout: u64) -> Result<()> {
    let pid_file_path = config::pid_file(&cfg.name)?;
    if !pid_file_path.exists() {
        info!(cluster = %cfg.name, "no PID file found, VM not running");
        return Ok(());
    }

    let pid_str = std::fs::read_to_string(&pid_file_path).context("reading PID file")?;
    let pid: i32 = pid_str.trim().parse().context("parsing PID")?;

    // Send shutdown command via SSH
    info!(cluster = %cfg.name, "sending shutdown command via SSH");
    let _ = tokio::process::Command::new("ssh")
        .args([
            "-p",
            &cfg.ssh_port.to_string(),
            "-o",
            "StrictHostKeyChecking=no",
            "-o",
            "UserKnownHostsFile=/dev/null",
            "-o",
            "ConnectTimeout=5",
            "-o",
            "LogLevel=ERROR",
            "root@localhost",
            "shutdown",
            "-h",
            "now",
        ])
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()
        .await;

    // Wait for process to exit
    info!(pid = pid, timeout = timeout, "waiting for VM process to exit");
    let deadline = tokio::time::Instant::now() + tokio::time::Duration::from_secs(timeout);

    loop {
        if !libc_kill(pid) {
            info!(pid = pid, "VM process exited");
            break;
        }
        if tokio::time::Instant::now() >= deadline {
            anyhow::bail!(
                "VM process {} did not exit within {}s timeout",
                pid,
                timeout
            );
        }
        tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;
    }

    // Clean up PID file
    cleanup_pid_file(&cfg.name)?;

    Ok(())
}

/// Remove the PID file for a cluster.
pub fn cleanup_pid_file(cluster: &str) -> Result<()> {
    let pid_file = config::pid_file(cluster)?;
    if pid_file.exists() {
        std::fs::remove_file(&pid_file)
            .with_context(|| format!("removing PID file {}", pid_file.display()))?;
    }
    Ok(())
}

/// Read the PID from the PID file, if it exists.
pub fn read_pid(cluster: &str) -> Result<Option<u32>> {
    let path = config::pid_file(cluster)?;
    if !path.exists() {
        return Ok(None);
    }
    let pid_str = std::fs::read_to_string(&path).context("reading PID file")?;
    let pid: u32 = pid_str.trim().parse().context("parsing PID")?;
    Ok(Some(pid))
}
