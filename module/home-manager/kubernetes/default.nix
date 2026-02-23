{
  lib,
  pkgs,
  config,
  ...
}:
with lib; let
  cfg = config.blackmatter.components.kubernetes;

  # Tool definitions — maps tool name to package expression.
  # Uses fallback pattern: (blackmatter-X or X) for cross-platform compat.
  allTools = with pkgs; {
    # Core CLI
    kubectl = (blackmatter-kubectl or kubectl);
    k9s = (blackmatter-k9s or k9s);
    helm = (blackmatter-helm or kubernetes-helm);
    kubectx = (blackmatter-kubectx or kubectx);

    # GitOps & deployment
    fluxcd = (blackmatter-fluxcd or fluxcd);
    stern = (blackmatter-stern or stern);
    kubecolor = (blackmatter-kubecolor or kubecolor);
    kustomize = (blackmatter-kustomize or kustomize);
    helmfile = (blackmatter-helmfile or helmfile);
    argocd = (blackmatter-argocd or argocd);
    kapp = (blackmatter-kapp or kapp);
    timoni = (blackmatter-timoni or timoni);
    tektoncd-cli = (blackmatter-tektoncd-cli or tektoncd-cli);
    argo-rollouts = (blackmatter-argo-rollouts or argo-rollouts);

    # Analysis & validation
    kube-score = (blackmatter-kube-score or kube-score);
    kubectl-tree = (blackmatter-kubectl-tree or kubectl-tree);
    kubeconform = (blackmatter-kubeconform or kubeconform);
    kube-linter = (blackmatter-kube-linter or kube-linter);

    # Security & policy
    kubeseal = (blackmatter-kubeseal or kubeseal);
    trivy = (blackmatter-trivy or trivy);
    grype = (blackmatter-grype or grype);
    cosign = (blackmatter-cosign or cosign);
    kyverno = (blackmatter-kyverno or kyverno);
    conftest = (blackmatter-conftest or conftest);
    kubescape = (blackmatter-kubescape or kubescape);
    falcoctl = (blackmatter-falcoctl or falcoctl);
    open-policy-agent = (blackmatter-open-policy-agent or open-policy-agent);
    step-cli = (blackmatter-step-cli or step-cli);

    # kubectl plugins
    popeye = (blackmatter-popeye or popeye);
    pluto = (blackmatter-pluto or pluto);
    kubent = (blackmatter-kubent or kubent);
    kor = (blackmatter-kor or kor);
    kube-capacity = (blackmatter-kube-capacity or kube-capacity);
    kubectl-neat = (blackmatter-kubectl-neat or kubectl-neat);
    kubectl-images = (blackmatter-kubectl-images or kubectl-images);
    krew = (blackmatter-krew or krew);
    kubectl-ktop = (blackmatter-kubectl-ktop or kubectl-ktop);
    kubeshark = (blackmatter-kubeshark or kubeshark);
    kubectl-cnpg = (blackmatter-kubectl-cnpg or kubectl-cnpg);
    kubevirt = (blackmatter-kubevirt or kubevirt);

    # Helm ecosystem
    helm-diff = (blackmatter-helm-diff or helm-diff);
    helm-docs = (blackmatter-helm-docs or helm-docs);

    # Container/image tools
    crane = (blackmatter-crane or crane);
    ko = (blackmatter-ko or ko);

    # Service mesh CLIs
    istioctl = (blackmatter-istioctl or istioctl);
    linkerd = (blackmatter-linkerd or linkerd);
    hubble = (blackmatter-hubble or hubble);
    cmctl = (blackmatter-cmctl or cmctl);

    # Cluster management
    clusterctl = (blackmatter-clusterctl or clusterctl);
    talosctl = (blackmatter-talosctl or talosctl);
    vcluster = (blackmatter-vcluster or vcluster);
    crossplane-cli = (blackmatter-crossplane-cli or crossplane-cli);
    kompose = (blackmatter-kompose or kompose);
    velero = (blackmatter-velero or velero);

    # Observability
    thanos = (blackmatter-thanos or thanos);
    logcli = (blackmatter-logcli or logcli);
    tempo-cli = (blackmatter-tempo-cli or tempo-cli);
    mimirtool = (blackmatter-mimirtool or mimirtool);
    coredns = (blackmatter-coredns or coredns);
    kube-state-metrics = (blackmatter-kube-state-metrics or kube-state-metrics);

    # Load testing
    k6 = (blackmatter-k6 or k6);
    vegeta = (blackmatter-vegeta or vegeta);
    hey = (blackmatter-hey or hey);
    fortio = (blackmatter-fortio or fortio);

    # Development
    kubebuilder = (blackmatter-kubebuilder or kubebuilder);
    operator-sdk = (blackmatter-operator-sdk or operator-sdk);
    etcd = (blackmatter-etcd or etcd);
    cilium-cli = (blackmatter-cilium-cli or cilium-cli);
    kwok = (blackmatter-kwok or kwok);
  };

  # Profile definitions — which tools are enabled per profile
  profileTools = {
    minimal = [
      "kubectl" "helm" "k9s" "kubectx"
    ];
    standard = profileTools.minimal ++ [
      "fluxcd" "stern" "kubecolor" "kube-score" "kubectl-tree"
      "helmfile" "kustomize" "kubeseal" "kubeconform"
      "popeye" "pluto" "kubent" "kor"
    ];
    full = attrNames allTools;
  };

  # Resolve enabled tools: start from profile, apply per-tool overrides
  profileDefaults = listToAttrs (map (name: nameValuePair name true) profileTools.${cfg.profile});
  toolOverrides = mapAttrs (_: t: t.enable) (filterAttrs (_: t: t ? enable) cfg.tools);
  enabledTools = profileDefaults // toolOverrides;

  # Build final package list
  packages = filter (p: p != null) (mapAttrsToList (name: enabled:
    if enabled && allTools ? ${name} then allTools.${name} else null
  ) enabledTools);
in {
  imports = [
    ./k3d
    ./kubectl  # Kubeconfig management, aliases, completion
    ../k9s     # K9s TUI with Nord theme
  ];

  options.blackmatter.components.kubernetes = {
    enable = mkEnableOption "kubernetes";

    profile = mkOption {
      type = types.enum [ "minimal" "standard" "full" ];
      default = "standard";
      description = ''
        Tool profile:
        - minimal: kubectl, helm, k9s, kubectx
        - standard: minimal + gitops, validation, and kubectl plugins
        - full: all cross-platform tools in the repository
      '';
    };

    tools = mkOption {
      type = types.attrsOf (types.submodule {
        options.enable = mkOption {
          type = types.bool;
          description = "Whether to enable this tool (overrides profile default)";
        };
      });
      default = {};
      description = ''
        Per-tool overrides. Takes precedence over the selected profile.
        Example: { trivy.enable = true; kubeseal.enable = false; }
      '';
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      # Enable k9s with Nord theme when k9s is in the tool set
      blackmatter.components.k9s.enable = mkDefault (enabledTools.k9s or false);

      home.packages = packages;

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
