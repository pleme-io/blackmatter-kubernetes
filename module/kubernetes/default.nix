{
  lib,
  pkgs,
  config,
  ...
}:
with lib; let
  cfg = config.blackmatter.components.kubernetes;
in {
  imports = [
    ./k3d
    ./k9s  # K9s TUI with Nord theme
  ];

  options = {
    blackmatter = {
      components = {
        kubernetes.enable = mkEnableOption "kubernetes";
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      # Enable k9s with Nord theme by default
      blackmatter.components.k9s.enable = mkDefault true;

      home.packages = with pkgs; [
        kubectl
        k9s
        # kubernetes-helm # Already installed via nix-env
        kind
        kubectx
        stern         # Multi-pod log tailing
        kubecolor     # Colorized kubectl output
        kube-score    # Kubernetes object analysis
        kubectl-tree  # Show tree of k8s objects
        helmfile      # Declarative helm chart management
        kustomize     # Kubernetes config customization
        kubeseal      # Sealed secrets
        kubeval       # Validate k8s manifests
        popeye        # K8s cluster sanitizer
        fluxcd        # GitOps continuous delivery for Kubernetes
      ];
      
      # Add helpful aliases
      # Note: klog and kexec are functions in shell/groups/functions/init.zsh (interactive with fzf)
      programs.zsh.shellAliases = mkIf config.programs.zsh.enable {
        k = "kubectl";
        kgp = "kubectl get pods";
        kgs = "kubectl get svc";
        kgn = "kubectl get nodes";
        kaf = "kubectl apply -f";
        kdel = "kubectl delete";
        kctx = "kubectx";
        kns = "kubens";
      };

      programs.bash.shellAliases = mkIf config.programs.bash.enable {
        k = "kubectl";
        kgp = "kubectl get pods";
        kgs = "kubectl get svc";
        kgn = "kubectl get nodes";
        kaf = "kubectl apply -f";
        kdel = "kubectl delete";
        kctx = "kubectx";
        kns = "kubens";
      };
    })
  ];
}
