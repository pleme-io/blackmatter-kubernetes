# NixOS kubectl module — system-wide kubectl, kubeconfig, and cluster tools
#
# Provides services.blackmatter.kubectl for NixOS systems.
# For multi-user kubeconfig setup, context-switching scripts, and system packages.
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.blackmatter.kubectl;

  # Generate context-switching scripts for each cluster
  clusterScripts = mapAttrsToList (name: clusterCfg:
    pkgs.writeShellScriptBin "k${name}" ''
      kubectl config use-context ${clusterCfg.context or name}
      echo "Switched to cluster: ${name}"
    ''
  ) cfg.clusters;

in {
  options.services.blackmatter.kubectl = {
    enable = mkEnableOption "kubectl and Kubernetes tools";

    distribution = mkOption {
      type = types.nullOr (types.enum [ "1.34" "1.35" ]);
      default = null;
      description = ''
        When set, documents which K8s version this node targets.
        kubectl 1.35.0 is within skew policy for both 1.34 and 1.35 clusters.
      '';
    };

    kubeconfigContent = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Full kubeconfig YAML content (overrides auto-generation)";
    };

    kubeconfigUsers = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Users to setup ~/.kube/config for";
    };

    clusters = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          server = mkOption {
            type = types.str;
            description = "API server URL";
          };
          context = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Context name (defaults to cluster name)";
          };
        };
      });
      default = {};
      description = "Cluster definitions for context-switching scripts";
    };

    packages = mkOption {
      type = types.listOf types.package;
      default = with pkgs; [
        (blackmatter-kubectl or kubectl)
        (blackmatter-k9s or k9s)
        (blackmatter-helm or kubernetes-helm)
        (blackmatter-kubectx or kubectx)
        (blackmatter-stern or stern)
        (blackmatter-kubecolor or kubecolor)
        (blackmatter-kube-score or kube-score)
        (blackmatter-kubectl-tree or kubectl-tree)
        (blackmatter-fluxcd or fluxcd)
        (blackmatter-kustomize or kustomize)
        (blackmatter-helmfile or helmfile)
        (blackmatter-kubeconform or kubeconform)
      ];
      description = "Kubernetes tools to install system-wide";
    };

    shellAliases = mkOption {
      type = types.attrsOf types.str;
      default = {
        k = "kubectl";
        kgp = "kubectl get pods";
        kgs = "kubectl get svc";
        kgn = "kubectl get nodes";
        kaf = "kubectl apply -f";
        kdel = "kubectl delete";
        klog = "kubectl logs";
        kexec = "kubectl exec -it";
      };
      description = "kubectl shell aliases";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = cfg.packages ++ clusterScripts;
    environment.shellAliases = cfg.shellAliases;
  };
}
