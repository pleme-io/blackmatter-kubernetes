use anyhow::Result;
use clap::{Parser, Subcommand};
use std::process::ExitCode;

mod config;
mod daemon;
mod destroy;
mod disk;
mod down;
mod health;
mod init;
mod sops;
mod status;
mod up;
mod vm;

#[derive(Parser)]
#[command(name = "kikai", version, about = "K3s cluster lifecycle orchestrator")]
struct Cli {
    /// Enable JSON log output (for systemd journal)
    #[arg(long, global = true)]
    json: bool,

    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Pre-generate cluster bootstrap secrets (age key, k3s token, admin password)
    Init {
        /// Cluster name (e.g., ryn-k3s)
        #[arg(long)]
        cluster: String,

        /// Path to SOPS-encrypted secrets file
        #[arg(long, default_value = "secrets.yaml")]
        secrets_file: String,

        /// Path to .sops.yaml config
        #[arg(long, default_value = ".sops.yaml")]
        sops_yaml: String,

        /// Dry-run: generate secrets but don't store them
        #[arg(long)]
        dry_run: bool,
    },

    /// Bring up a k3s cluster (build image, create disks, launch VM, wait for health)
    Up {
        /// Cluster name (e.g., ryn-k3s)
        #[arg(long)]
        cluster: String,

        /// Number of vCPUs
        #[arg(long, default_value = "4")]
        cpus: u32,

        /// Memory in MiB
        #[arg(long, default_value = "8192")]
        memory: u32,

        /// Data disk size (sparse) e.g. "50G"
        #[arg(long, default_value = "50G")]
        disk_size: String,

        /// Host port for K8s API (forwarded to guest 6443)
        #[arg(long, default_value = "6443")]
        api_port: u16,

        /// Host port for SSH (forwarded to guest 22)
        #[arg(long, default_value = "2222")]
        ssh_port: u16,

        /// Path to SOPS-encrypted secrets file
        #[arg(long, default_value = "secrets.yaml")]
        secrets_file: String,

        /// Path to .sops.yaml config
        #[arg(long, default_value = ".sops.yaml")]
        sops_yaml: String,

        /// Path to nix flake (for building the image)
        #[arg(long, default_value = ".")]
        nix_flake: String,

        /// Skip seed disk provisioning (use existing)
        #[arg(long)]
        no_seed: bool,

        /// Skip waiting for cluster health after launch
        #[arg(long)]
        no_wait: bool,
    },

    /// Gracefully shut down a running cluster VM
    Down {
        /// Cluster name
        #[arg(long)]
        cluster: String,

        /// Host port for SSH (forwarded to guest 22)
        #[arg(long, default_value = "2222")]
        ssh_port: u16,

        /// Shutdown timeout in seconds
        #[arg(long, default_value = "120")]
        timeout: u64,
    },

    /// Show cluster health status
    Status {
        /// Cluster name
        #[arg(long)]
        cluster: String,

        /// Host port for K8s API (forwarded to guest 6443)
        #[arg(long, default_value = "6443")]
        api_port: u16,
    },

    /// Destroy cluster (stop VM, remove data)
    Destroy {
        /// Cluster name
        #[arg(long)]
        cluster: String,

        /// Host port for SSH (forwarded to guest 22)
        #[arg(long, default_value = "2222")]
        ssh_port: u16,

        /// Also remove secrets from SOPS
        #[arg(long)]
        remove_secrets: bool,

        /// Force destroy without confirmation
        #[arg(long)]
        force: bool,
    },

    /// Run continuous health monitoring daemon
    Daemon {
        /// Cluster name
        #[arg(long)]
        cluster: String,

        /// Number of vCPUs
        #[arg(long, default_value = "4")]
        cpus: u32,

        /// Memory in MiB
        #[arg(long, default_value = "8192")]
        memory: u32,

        /// Data disk size (sparse) e.g. "50G"
        #[arg(long, default_value = "50G")]
        disk_size: String,

        /// Host port for K8s API (forwarded to guest 6443)
        #[arg(long, default_value = "6443")]
        api_port: u16,

        /// Host port for SSH (forwarded to guest 22)
        #[arg(long, default_value = "2222")]
        ssh_port: u16,

        /// Path to SOPS-encrypted secrets file
        #[arg(long, default_value = "secrets.yaml")]
        secrets_file: String,

        /// Path to .sops.yaml config
        #[arg(long, default_value = ".sops.yaml")]
        sops_yaml: String,

        /// Path to nix flake (for building the image)
        #[arg(long, default_value = ".")]
        nix_flake: String,

        /// Health check interval in seconds
        #[arg(long, default_value = "30")]
        interval: u64,

        /// Consecutive failures before restart
        #[arg(long, default_value = "3")]
        max_failures: u32,
    },
}

#[tokio::main]
async fn main() -> ExitCode {
    let cli = Cli::parse();
    init_tracing(cli.json);

    match run(cli.command, cli.json).await {
        Ok(code) => code,
        Err(e) => {
            tracing::error!(error = %e, "fatal");
            ExitCode::FAILURE
        }
    }
}

async fn run(cmd: Command, json_output: bool) -> Result<ExitCode> {
    match cmd {
        Command::Init {
            cluster,
            secrets_file,
            sops_yaml,
            dry_run,
        } => {
            let cfg = config::ClusterConfig {
                name: cluster,
                secrets_file,
                sops_yaml,
                ..config::ClusterConfig::default()
            };
            init::run(&cfg, dry_run).await
        }
        Command::Up {
            cluster,
            cpus,
            memory,
            disk_size,
            api_port,
            ssh_port,
            secrets_file,
            sops_yaml,
            nix_flake,
            no_seed,
            no_wait,
        } => {
            let cfg = config::ClusterConfig {
                name: cluster,
                cpus,
                memory,
                disk_size,
                api_port,
                ssh_port,
                secrets_file,
                sops_yaml,
                nix_flake,
            };
            up::run(&cfg, no_seed, no_wait).await
        }
        Command::Down {
            cluster,
            ssh_port,
            timeout,
        } => {
            let cfg = config::ClusterConfig {
                name: cluster,
                ssh_port,
                ..config::ClusterConfig::default()
            };
            down::run(&cfg, timeout).await
        }
        Command::Status {
            cluster,
            api_port,
        } => {
            let cfg = config::ClusterConfig {
                name: cluster,
                api_port,
                ..config::ClusterConfig::default()
            };
            status::run(&cfg, json_output).await
        }
        Command::Destroy {
            cluster,
            ssh_port,
            remove_secrets,
            force,
        } => {
            let cfg = config::ClusterConfig {
                name: cluster,
                ssh_port,
                ..config::ClusterConfig::default()
            };
            destroy::run(&cfg, remove_secrets, force).await
        }
        Command::Daemon {
            cluster,
            cpus,
            memory,
            disk_size,
            api_port,
            ssh_port,
            secrets_file,
            sops_yaml,
            nix_flake,
            interval,
            max_failures,
        } => {
            let cfg = config::ClusterConfig {
                name: cluster,
                cpus,
                memory,
                disk_size,
                api_port,
                ssh_port,
                secrets_file,
                sops_yaml,
                nix_flake,
            };
            daemon::run(&cfg, interval, max_failures).await
        }
    }
}

fn init_tracing(json: bool) {
    use tracing_subscriber::{fmt, EnvFilter};

    let filter =
        EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));
    if json {
        fmt().json().with_env_filter(filter).init();
    } else {
        fmt().with_env_filter(filter).init();
    }
}
