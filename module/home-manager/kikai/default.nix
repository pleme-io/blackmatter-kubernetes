# blackmatter.components.kubernetes.clusters — kikai cluster lifecycle management
#
# Declarative k3s VM cluster definitions with optional launchd auto-start.
# Each cluster entry generates:
#   - A config entry in ~/.config/kikai/clusters.yaml
#   - A launchd agent (if autoStart = true) running kikai daemon
#
# Usage:
#   blackmatter.components.kubernetes.clusters.ryn-k3s = {
#     enable = true;
#     cpus = 4;
#     memory = 8192;
#     autoStart = true;
#   };
{ config, lib, pkgs, ... }:

let
  cfg = config.blackmatter.components.kubernetes;
  enabledClusters = lib.filterAttrs (_: c: c.enable) cfg.clusters;
  homeDir = config.home.homeDirectory;

  # kikai binary — comes from the blackmatter-kubernetes overlay
  kikaiPkg = pkgs.blackmatter-kikai or pkgs.kikai or (throw "kikai package not found in pkgs");

  # Runtime tools that kikai shells out to
  runtimeDeps = with pkgs; [
    sops age openssl yq-go kubectl
  ];

  # Generate clusters.yaml content
  clustersYaml = lib.mapAttrs (_name: c: {
    cpus = c.cpus;
    memory = c.memory;
    disk_size = c.diskSize;
    api_port = c.apiPort;
    ssh_port = c.sshPort;
    secrets_file = c.secretsFile;
    sops_yaml = c.sopsYaml;
    nix_flake = c.nixFlake;
  }) enabledClusters;
in {
  options.blackmatter.components.kubernetes.clusters = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "this k3s VM cluster";

        cpus = lib.mkOption {
          type = lib.types.int;
          default = 4;
          description = "Number of vCPUs for the VM.";
        };

        memory = lib.mkOption {
          type = lib.types.int;
          default = 8192;
          description = "Memory in MiB for the VM.";
        };

        diskSize = lib.mkOption {
          type = lib.types.str;
          default = "50G";
          description = "Data disk size (sparse allocation).";
        };

        apiPort = lib.mkOption {
          type = lib.types.port;
          default = 6443;
          description = "Host port forwarded to guest 6443 (k8s API).";
        };

        sshPort = lib.mkOption {
          type = lib.types.port;
          default = 2222;
          description = "Host port forwarded to guest 22 (SSH).";
        };

        nixFlake = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Flake reference for building the VM image.";
        };

        secretsFile = lib.mkOption {
          type = lib.types.str;
          default = "secrets.yaml";
          description = "Path to SOPS-encrypted secrets file.";
        };

        sopsYaml = lib.mkOption {
          type = lib.types.str;
          default = ".sops.yaml";
          description = "Path to .sops.yaml config.";
        };

        autoStart = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Auto-start cluster via launchd on login.";
        };

        healthCheck = {
          interval = lib.mkOption {
            type = lib.types.int;
            default = 60;
            description = "Health check interval in seconds.";
          };

          maxFailures = lib.mkOption {
            type = lib.types.int;
            default = 3;
            description = "Consecutive failures before VM restart.";
          };
        };
      };
    });
    default = {};
    description = "Kubernetes cluster definitions managed by kikai.";
  };

  config = lib.mkIf (enabledClusters != {}) {
    # Add kikai to user packages
    home.packages = [ kikaiPkg ];

    # Write cluster config file
    xdg.configFile."kikai/clusters.yaml".text =
      builtins.toJSON clustersYaml;

    # Generate launchd agents for auto-start clusters
    launchd.agents = lib.mapAttrs' (name: clusterCfg:
      lib.nameValuePair "kikai-${name}" {
        enable = clusterCfg.autoStart;
        config = {
          Label = "io.pleme.kikai.${name}";
          ProgramArguments = [
            "${kikaiPkg}/bin/kikai" "daemon"
            "--cluster" name
            "--json"
            "--interval" (toString clusterCfg.healthCheck.interval)
            "--max-failures" (toString clusterCfg.healthCheck.maxFailures)
          ];
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "${homeDir}/Library/Logs/kikai-${name}.log";
          StandardErrorPath = "${homeDir}/Library/Logs/kikai-${name}.err";
          EnvironmentVariables = {
            PATH = lib.makeBinPath runtimeDeps + ":/usr/bin:/bin:/usr/sbin";
          };
        };
      }
    ) enabledClusters;
  };
}
