{
  lib,
  pkgs,
  config,
  ...
}:
with lib; let
  cfg = config.blackmatter.components.kubernetes;

  # Tool definitions — maps tool name to package expression.
  # Prefers blackmatter-built overlay packages (Go monorepo), falls back to nixpkgs.
  # Uses pkgs.attr or default syntax (bare identifiers + `or` keyword don't work in Nix).
  bm = name: fallback: pkgs.${"blackmatter-${name}"} or fallback;

  allTools = {
    # Core CLI
    kubectl = bm "kubectl" pkgs.kubectl;
    k9s = bm "k9s" pkgs.k9s;
    helm = bm "helm" pkgs.kubernetes-helm;
    kubectx = bm "kubectx" pkgs.kubectx;

    # GitOps & deployment
    fluxcd = bm "fluxcd" pkgs.fluxcd;
    stern = bm "stern" pkgs.stern;
    kubecolor = bm "kubecolor" pkgs.kubecolor;
    kustomize = bm "kustomize" pkgs.kustomize;
    helmfile = bm "helmfile" pkgs.helmfile;
    argocd = bm "argocd" pkgs.argocd;
    kapp = bm "kapp" pkgs.kapp;
    timoni = bm "timoni" pkgs.timoni;
    tektoncd-cli = bm "tektoncd-cli" pkgs.tektoncd-cli;
    argo-rollouts = bm "argo-rollouts" pkgs.argo-rollouts;

    # Analysis & validation
    kube-score = bm "kube-score" pkgs.kube-score;
    kubectl-tree = bm "kubectl-tree" pkgs.kubectl-tree;
    kubeconform = bm "kubeconform" pkgs.kubeconform;
    kube-linter = bm "kube-linter" pkgs.kube-linter;

    # Security & policy
    kubeseal = bm "kubeseal" pkgs.kubeseal;
    trivy = bm "trivy" pkgs.trivy;
    grype = bm "grype" pkgs.grype;
    cosign = bm "cosign" pkgs.cosign;
    kyverno = bm "kyverno" pkgs.kyverno;
    conftest = bm "conftest" pkgs.conftest;
    kubescape = bm "kubescape" pkgs.kubescape;
    falcoctl = bm "falcoctl" pkgs.falcoctl;
    open-policy-agent = bm "open-policy-agent" pkgs.open-policy-agent;
    step-cli = bm "step-cli" pkgs.step-cli;

    # kubectl plugins
    popeye = bm "popeye" pkgs.popeye;
    pluto = bm "pluto" pkgs.pluto;
    kubent = bm "kubent" pkgs.kubent;
    kor = bm "kor" pkgs.kor;
    kube-capacity = bm "kube-capacity" pkgs.kube-capacity;
    kubectl-neat = bm "kubectl-neat" pkgs.kubectl-neat;
    kubectl-images = bm "kubectl-images" pkgs.kubectl-images;
    krew = bm "krew" pkgs.krew;
    kubectl-ktop = bm "kubectl-ktop" pkgs.kubectl-ktop;
    kubeshark = bm "kubeshark" pkgs.kubeshark;
    kubectl-cnpg = bm "kubectl-cnpg" pkgs.kubectl-cnpg;
    kubevirt = bm "kubevirt" pkgs.kubevirt;

    # Helm ecosystem
    helm-diff = bm "helm-diff" pkgs.helm-diff;
    helm-docs = bm "helm-docs" pkgs.helm-docs;

    # Container/image tools
    crane = bm "crane" pkgs.crane;
    ko = bm "ko" pkgs.ko;

    # Service mesh CLIs
    istioctl = bm "istioctl" pkgs.istioctl;
    linkerd = bm "linkerd" pkgs.linkerd;
    hubble = bm "hubble" pkgs.hubble;
    cmctl = bm "cmctl" pkgs.cmctl;

    # Cluster management
    clusterctl = bm "clusterctl" pkgs.clusterctl;
    talosctl = bm "talosctl" pkgs.talosctl;
    vcluster = bm "vcluster" pkgs.vcluster;
    crossplane-cli = bm "crossplane-cli" pkgs.crossplane-cli;
    kompose = bm "kompose" pkgs.kompose;
    kind = bm "kind" pkgs.kind;
    velero = bm "velero" pkgs.velero;

    # Observability
    thanos = bm "thanos" pkgs.thanos;
    logcli = bm "logcli" pkgs.logcli;
    tempo-cli = bm "tempo-cli" pkgs.tempo-cli;
    mimirtool = bm "mimirtool" pkgs.mimirtool;
    coredns = bm "coredns" pkgs.coredns;
    kube-state-metrics = bm "kube-state-metrics" pkgs.kube-state-metrics;

    # Load testing
    k6 = bm "k6" pkgs.k6;
    vegeta = bm "vegeta" pkgs.vegeta;
    hey = bm "hey" pkgs.hey;
    fortio = bm "fortio" pkgs.fortio;

    # Development
    kubebuilder = bm "kubebuilder" pkgs.kubebuilder;
    operator-sdk = bm "operator-sdk" pkgs.operator-sdk;
    etcd = bm "etcd" pkgs.etcd;
    cilium-cli = bm "cilium-cli" pkgs.cilium-cli;
    kwok = bm "kwok" pkgs.kwok;
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
    ./kind
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
