# Kubectl configuration — kubeconfig management, aliases, completion
#
# Generic module for managing kubectl access to Kubernetes clusters.
# All cluster-specific data (servers, names, credentials) is passed in via
# options — this module contains no identifying information.
#
# Usage:
#   blackmatter.components.kubernetes.kubectl = {
#     enable = true;
#     kubeconfig = "apiVersion: v1\nclusters: ...";
#     clusters = ["staging" "production"];
#     editor = "nvim";
#   };
{
  lib,
  pkgs,
  config,
  ...
}:
with lib; let
  cfg = config.blackmatter.components.kubernetes.kubectl;

  # Create quick-switch script for a cluster context
  mkClusterScript = name: pkgs.writeScriptBin "k${name}" ''
    #!${pkgs.bash}/bin/bash
    kubectl config use-context ${name} > /dev/null 2>&1
    kubectl "$@"
  '';
in {
  options.blackmatter.components.kubernetes.kubectl = {
    enable = mkEnableOption "kubectl configuration and kubeconfig management";

    kubeconfig = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Full kubeconfig YAML content (clusters + contexts).
        Credentials/users should be managed separately (e.g., via SOPS)
        and merged via KUBECONFIG env var.
        If null, no kubeconfig file will be managed.
      '';
    };

    kubeconfigPath = mkOption {
      type = types.str;
      default = ".kube/config";
      description = "Path relative to $HOME for the kubeconfig file";
    };

    clusters = mkOption {
      type = types.listOf types.str;
      default = [];
      description = ''
        List of cluster context names to create quick-switch scripts for.
        Each name generates a k<name> script (e.g., clusters = ["prod"] → kprod command).
      '';
      example = [ "staging" "production" "production-tunnel" ];
    };

    enableAliases = mkOption {
      type = types.bool;
      default = true;
      description = "Enable standard kubectl shell aliases (k, kgp, kgs, etc.)";
    };

    enableCompletion = mkOption {
      type = types.bool;
      default = true;
      description = "Enable kubectl zsh completion";
    };

    editor = mkOption {
      type = types.str;
      default = "nvim";
      description = "Default editor for kubectl edit (KUBE_EDITOR)";
    };
  };

  config = mkIf cfg.enable {
    # Install cluster quick-switch scripts
    home.packages = map mkClusterScript cfg.clusters;

    # Write kubeconfig file
    home.file.${cfg.kubeconfigPath} = mkIf (cfg.kubeconfig != null) {
      force = true;
      text = cfg.kubeconfig;
    };

    # Set KUBE_EDITOR
    home.sessionVariables = {
      KUBE_EDITOR = cfg.editor;
    };

    # Kubectl aliases (extends the base aliases from the kubernetes component)
    programs.zsh.shellAliases = mkIf (cfg.enableAliases && config.programs.zsh.enable) (
      {
        klog = "kubectl logs";
        kexec = "kubectl exec -it";
      }
      // (listToAttrs (map (cluster: {
        name = "kctx-${cluster}";
        value = "kubectl config use-context ${cluster}";
      }) cfg.clusters))
      // (listToAttrs (map (cluster: {
        name = "k${cluster}-nodes";
        value = "k${cluster} get nodes";
      }) cfg.clusters))
    );

    # Kubectl zsh completion
    programs.zsh.initExtra = mkIf (cfg.enableCompletion && config.programs.zsh.enable) ''
      # Kubectl completion
      if command -v kubectl &> /dev/null; then
        source <(kubectl completion zsh)
        complete -F __start_kubectl k
      fi
    '';
  };
}
