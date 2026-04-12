# NixOS FluxCD bootstrap module
#
# Declarative FluxCD deployment for any Kubernetes cluster.
# Generates component manifests from the flux CLI, writes sync config,
# and creates Kubernetes secrets from sops-nix managed host files.
#
# Supports two orchestrators:
#   - K3s:      manifests via auto-deploy directory, depends on k3s.service
#   - kubeadm:  manifests via kubectl apply, depends on kubelet.service
#
# Supports two auth methods:
#   - ssh:   SSH deploy key (identity + known_hosts secret)
#   - token: HTTPS personal access token (username + password secret)
#
# Boot sequence (K3s):
#   systemd-tmpfiles → writes manifests to k3s server/manifests/
#   k3s.service starts → applies gotk-components + gotk-sync
#   fluxcd-bootstrap.service → creates git auth + SOPS age key secrets
#   source-controller retries → auth secret exists → pulls git repo
#   kustomize-controller → reconciles cluster path → full cluster state
#
# Boot sequence (kubeadm):
#   kubelet.service starts → kubeadm init/join completes (via kindling-init)
#   fluxcd-bootstrap.service → applies gotk-components + gotk-sync + secrets
#   source-controller retries → auth secret exists → pulls git repo
#   kustomize-controller → reconciles cluster path → full cluster state
{ nixosHelpers }:

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.blackmatter.fluxcd;

  isSSH = cfg.source.auth == "ssh";
  isToken = cfg.source.auth == "token";

  # Detect which Kubernetes orchestrator is active.
  # K3s module is always imported via blackmatter aggregator.
  # The kubernetes module may or may not be imported.
  isK3s = config.services.blackmatter.k3s.enable;
  isK8s = (config.services.blackmatter.kubernetes.enable or false)
    || (config.virtualisation.containerd.enable or false);

  # Orchestrator-specific configuration
  k8sService = if isK3s then "k3s.service" else "kubelet.service";
  kubeconfig = if isK3s
    then "/etc/rancher/k3s/k3s.yaml"
    else "/etc/kubernetes/admin.conf";

  # Generate FluxCD component manifests from the flux CLI.
  # Manifests are embedded in the binary at build time — no network needed.
  fluxManifests = pkgs.runCommand "flux-manifests" {
    nativeBuildInputs = [ (pkgs.blackmatter-fluxcd or pkgs.fluxcd) ];
  } ''
    flux install --export > $out
  '';

  # Well-known GitHub SSH host keys (stable, published by GitHub)
  githubKnownHosts = ''
    github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
    github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
    github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZKyft98o3/GRs+JjiBxkg9g1/fPxVo/7FJj0oNw8rOLSTNqUf/Gkk8OOOFsJJTUGGxlV+FBkUpxkXAiqTk7B9VfAHEJqzJ2FnKhSKDMG1Oc/hqdwmT8snFzBQ2sQbvJaTtGC2QdNm0ZOAsj5zIWLjBbhOIGPH8gk8n4PVw9YOGrxFCB84rMSIvIV0N3gYrEOJzHWF4JDMRqwOjzb0FBMCG1A/bG5DPODMSXeJ84Evs7T1q0b+K2RWJbhL5y0bYSh5pCJz0IVlAvnI17F1L1M27kA0dAO1X0fqcqbCO5ymBMrA0eJPzJ4pREqyonMSCX0f1A5VAtDzB4BKPEB3BhRRFDMJ0bHEoB1C0gB0CcHB0oGqp/4rqbKkHtmJLarLFEJNL/B0OhK+0OBde1UtI14g3k0DOb5zRuEJHAn8q2yGeJgLJc='';

  knownHostsFile = pkgs.writeText "github-known-hosts" (
    if cfg.knownHosts != null then cfg.knownHosts else githubKnownHosts
  );

  # gotk-sync.yaml — GitRepository + root Kustomization
  syncManifest = ''
    ---
    apiVersion: source.toolkit.fluxcd.io/v1
    kind: GitRepository
    metadata:
      name: flux-system
      namespace: flux-system
    spec:
      interval: ${cfg.source.interval}
      ref:
        branch: ${cfg.source.branch}
      secretRef:
        name: flux-system
      url: ${cfg.source.url}
    ---
    apiVersion: kustomize.toolkit.fluxcd.io/v1
    kind: Kustomization
    metadata:
      name: flux-system
      namespace: flux-system
    spec:
      interval: ${cfg.reconcile.interval}
      path: ${cfg.reconcile.path}
      prune: ${boolToString cfg.reconcile.prune}
      sourceRef:
        kind: GitRepository
        name: flux-system
  '';

  # Build the kubectl command to create the git auth secret based on auth type.
  # SSH: secret with identity (private key) + known_hosts
  # Token: secret with username ("git") + password (PAT/token)
  gitAuthSecretCmd =
    if isSSH then ''
      kubectl create secret generic flux-system \
        --namespace flux-system \
        --from-file=identity=${cfg.source.sshKeyFile} \
        --from-file=known_hosts=${knownHostsFile} \
        --dry-run=client -o yaml | kubectl apply -f -
    ''
    else ''
      kubectl create secret generic flux-system \
        --namespace flux-system \
        --from-literal=username=${cfg.source.tokenUsername} \
        --from-file=password=${cfg.source.tokenFile} \
        --dry-run=client -o yaml | kubectl apply -f -
    '';

in {
  options.services.blackmatter.fluxcd = {
    enable = mkEnableOption "FluxCD GitOps bootstrap";

    source = {
      url = mkOption {
        type = types.str;
        default = "";
        description = "Git repository URL (SSH or HTTPS depending on auth method)";
        example = "https://github.com/pleme-io/k8s";
      };

      branch = mkOption {
        type = types.str;
        default = "main";
        description = "Git branch to track";
      };

      interval = mkOption {
        type = types.str;
        default = "1m0s";
        description = "Git source polling interval";
      };

      auth = mkOption {
        type = types.enum [ "ssh" "token" ];
        default = "ssh";
        description = "Authentication method for git access";
      };

      # SSH auth options
      sshKeyFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to SSH private key file (from sops-nix). Required when auth = ssh.";
        example = "/run/secrets/fluxcd-ssh-key";
      };

      # Token auth options
      tokenFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to file containing the access token (from sops-nix). Required when auth = token.";
        example = "/run/secrets/fluxcd-token";
      };

      tokenUsername = mkOption {
        type = types.str;
        default = "git";
        description = "Username for token auth (usually 'git' for GitHub PATs)";
      };
    };

    reconcile = {
      path = mkOption {
        type = types.str;
        default = ".";
        description = "Path within the repository to reconcile";
        example = "./clusters/plo";
      };

      interval = mkOption {
        type = types.str;
        default = "2m0s";
        description = "Kustomization reconciliation interval";
      };

      prune = mkOption {
        type = types.bool;
        default = true;
        description = "Remove resources no longer in Git";
      };
    };

    sops = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable SOPS age decryption for FluxCD";
      };

      ageKeyFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to age private key file (from sops-nix)";
        example = "/var/lib/sops-nix/key.txt";
      };
    };

    knownHosts = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "SSH known hosts content (defaults to GitHub's public keys). Only used with auth = ssh.";
    };

    conditionPath = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Path to sentinel file for FluxCD activation. When set,
        fluxcd-bootstrap.service only starts if this file exists.
        kindling-init creates the sentinel after writing secrets.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = isK3s || isK8s;
        message = "services.blackmatter.fluxcd requires either services.blackmatter.k3s or a Kubernetes orchestrator (kubeadm/containerd) to be enabled";
      }
      {
        assertion = cfg.conditionPath != null || cfg.source.url != "";
        message = "services.blackmatter.fluxcd.source.url must be set";
      }
      {
        assertion = cfg.conditionPath != null || !isSSH || cfg.source.sshKeyFile != null;
        message = "services.blackmatter.fluxcd.source.sshKeyFile is required when auth = ssh";
      }
      {
        assertion = cfg.conditionPath != null || !isToken || cfg.source.tokenFile != null;
        message = "services.blackmatter.fluxcd.source.tokenFile is required when auth = token";
      }
      {
        assertion = !cfg.sops.enable || cfg.sops.ageKeyFile != null;
        message = "services.blackmatter.fluxcd.sops.ageKeyFile is required when sops is enabled";
      }
    ];

    # K3s: write FluxCD manifests to auto-deploy directory.
    # K3s applies these automatically when it starts.
    #
    # gotk-components (CRDs + controllers): ALWAYS baked — cluster-agnostic.
    # gotk-sync (GitRepository + Kustomization): baked ONLY when NOT in
    # kindling-gated mode. In kindling-gated mode, kindling-init writes
    # the sync manifest at runtime with the actual repo URL from ClusterConfig.
    services.blackmatter.k3s.manifests = mkIf isK3s (
      { "gotk-components" = { content = builtins.readFile fluxManifests; }; }
      // optionalAttrs (cfg.conditionPath == null) {
        "gotk-sync" = { content = syncManifest; };
      }
    );

    # Bootstrap service: creates Kubernetes Secrets and (for non-K3s)
    # applies FluxCD component manifests via kubectl.
    systemd.services.fluxcd-bootstrap = {
      description = "Bootstrap FluxCD secrets into Kubernetes";
      after = [ k8sService ] ++ optional (cfg.conditionPath != null) "kindling-init.service";
      requires = [ k8sService ];
      unitConfig = mkIf (cfg.conditionPath != null) {
        ConditionPathExists = cfg.conditionPath;
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "fluxcd-bootstrap" ''
          export KUBECONFIG=${kubeconfig}
          export PATH=${makeBinPath [ (pkgs.blackmatter-kubectl or pkgs.kubectl) pkgs.coreutils ]}:$PATH

          # Wait for API server
          for i in $(seq 1 60); do
            kubectl get ns >/dev/null 2>&1 && break
            echo "Waiting for API server... ($i/60)"
            sleep 2
          done

          # Create namespace
          kubectl create namespace flux-system --dry-run=client -o yaml | kubectl apply -f -

          ${optionalString (!isK3s) ''
            # Apply FluxCD component manifests (K3s does this via auto-deploy)
            echo "Applying FluxCD components via kubectl..."
            kubectl apply -f ${fluxManifests}

            echo "Applying FluxCD sync manifest..."
            kubectl apply -f ${pkgs.writeText "gotk-sync.yaml" syncManifest}
          ''}

          # Create git auth secret
          ${gitAuthSecretCmd}

          ${optionalString cfg.sops.enable ''
            # Create SOPS age key secret
            kubectl create secret generic sops-age \
              --namespace flux-system \
              --from-file=age.agekey=${cfg.sops.ageKeyFile} \
              --dry-run=client -o yaml | kubectl apply -f -
          ''}

          echo "FluxCD bootstrap secrets created successfully"
        '';
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
