{
  description = "Blackmatter Kubernetes - K8s tools, K9s TUI, K3d, k3s, and cluster management";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/d6c71932130818840fc8fe9509cf50be8c64634f";
    substrate = {
      url = "github:pleme-io/substrate";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    blackmatter-go = {
      url = "github:pleme-io/blackmatter-go";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, substrate, blackmatter-go }:
  let
    # k3s + tools are Linux-only; HM modules are cross-platform
    linuxSystems = [ "x86_64-linux" "aarch64-linux" ];

    # Cross-platform systems (for tools that work on macOS too)
    allSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

    # Go overlay — builds Go from upstream source via blackmatter-go
    goOverlay = (import "${blackmatter-go}/lib/overlay.nix").mkGoOverlay {};

    # Go tool builder from blackmatter-go
    goToolBuilder = import "${blackmatter-go}/lib/tool.nix";
    mkGoTool = goToolBuilder.mkGoTool;

    nixosHelpers = import "${substrate}/lib/nixos-service-helpers.nix" {
      lib = nixpkgs.lib;
    };

    mkPkgs = system: import nixpkgs {
      inherit system;
      config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [
        "consul"  # BSL 1.1
      ];
      overlays = [
        goOverlay
        self.overlays.default
      ];
    };

    forEachLinuxSystem = f: nixpkgs.lib.genAttrs linuxSystems (system: f {
      inherit system;
      pkgs = mkPkgs system;
    });

    forEachSystem = f: nixpkgs.lib.genAttrs allSystems (system: f {
      inherit system;
      pkgs = mkPkgs system;
    });

    k3sModule = self.nixosModules.k3s;

    # Profile definitions (pure data)
    profileDefs = import ./lib/profiles.nix { lib = nixpkgs.lib; };

    # Map profile extraPackages names to overlay package names
    resolveProfilePackages = pkgs: profileName: let
      profile = profileDefs.profiles.${profileName};
      resolve = name: pkgs.${"blackmatter-${name}"};
    in [ (pkgs.blackmatter-k3s or pkgs.k3s) ] ++ map resolve profile.extraPackages;

  in {
    # ── Home-manager modules (cross-platform) ───────────────────────
    homeManagerModules.default = import ./module/home-manager;

    # ── NixOS modules (Linux-only) ──────────────────────────────────
    nixosModules.k3s = import ./module/nixos/k3s { inherit nixosHelpers; };
    nixosModules.kubectl = import ./module/nixos/kubectl;

    # ── Overlay ─────────────────────────────────────────────────────
    overlays.default = nixpkgs.lib.composeManyExtensions [
      goOverlay
      (final: prev: let
        tools = import ./pkgs/tools { inherit mkGoTool; pkgs = final; };
        network = import ./pkgs/network { inherit mkGoTool; pkgs = final; };
        security = import ./pkgs/security { inherit mkGoTool; pkgs = final; };
        cluster = import ./pkgs/cluster { inherit mkGoTool; pkgs = final; };
        gitops = import ./pkgs/gitops { inherit mkGoTool; pkgs = final; };
        plugins = import ./pkgs/plugins { inherit mkGoTool; pkgs = final; };
        observability = import ./pkgs/observability { inherit mkGoTool; pkgs = final; };
        testing = import ./pkgs/testing { inherit mkGoTool; pkgs = final; };
      in {
        # ── k3s (Linux-only, 3-stage build) ─────────────────────────
        blackmatter-k3s = (import ./pkgs/k3s { inherit (final) lib callPackage; }).k3s_1_34;
        blackmatter-k3s-latest = (import ./pkgs/k3s { inherit (final) lib callPackage; }).k3s_1_35;

        # ── Core CLI tools ──────────────────────────────────────────
        blackmatter-kubectl = tools.kubectl;
        blackmatter-helm = tools.helm;
        blackmatter-k9s = tools.k9s;
        blackmatter-fluxcd = tools.fluxcd;
        blackmatter-kubectx = tools.kubectx;
        blackmatter-stern = tools.stern;
        blackmatter-kubecolor = tools.kubecolor;
        blackmatter-kube-score = tools.kube-score;
        blackmatter-kubectl-tree = tools.kubectl-tree;
        blackmatter-kustomize = tools.kustomize;
        blackmatter-cilium-cli = tools.cilium-cli;
        blackmatter-calicoctl = tools.calicoctl;

        # Container/image tools
        blackmatter-crane = tools.crane;
        blackmatter-nerdctl = tools.nerdctl;
        blackmatter-buildkit = tools.buildkit;
        blackmatter-ko = tools.ko;

        # Helm ecosystem
        blackmatter-helmfile = tools.helmfile;
        blackmatter-helm-diff = tools.helm-diff;
        blackmatter-helm-docs = tools.helm-docs;

        # Infrastructure
        blackmatter-etcd = tools.etcd;

        # Development frameworks
        blackmatter-kubebuilder = tools.kubebuilder;
        blackmatter-operator-sdk = tools.operator-sdk;

        # ── Network plugins & service meshes ────────────────────────
        blackmatter-cni-plugins = network.cni-plugins;
        blackmatter-flannel = network.flannel;
        blackmatter-cni-plugin-flannel = network.cni-plugin-flannel;
        blackmatter-multus-cni = network.multus-cni;
        blackmatter-calico-cni-plugin = network.calico-cni-plugin;
        blackmatter-calico-apiserver = network.calico-apiserver;
        blackmatter-calico-typha = network.calico-typha;
        blackmatter-calico-kube-controllers = network.calico-kube-controllers;
        blackmatter-calico-pod2daemon = network.calico-pod2daemon;
        blackmatter-confd-calico = network.confd-calico;
        blackmatter-istioctl = network.istioctl;
        blackmatter-linkerd = network.linkerd;
        blackmatter-hubble = network.hubble;
        blackmatter-cmctl = network.cmctl;

        # ── Security & policy ───────────────────────────────────────
        blackmatter-kubeseal = security.kubeseal;
        blackmatter-trivy = security.trivy;
        blackmatter-grype = security.grype;
        blackmatter-cosign = security.cosign;
        blackmatter-kyverno = security.kyverno;
        blackmatter-open-policy-agent = security.open-policy-agent;
        blackmatter-conftest = security.conftest;
        blackmatter-falcoctl = security.falcoctl;
        blackmatter-kubescape = security.kubescape;
        blackmatter-kube-linter = security.kube-linter;
        blackmatter-kubeconform = security.kubeconform;
        blackmatter-step-cli = security.step-cli;

        # ── Cluster management ──────────────────────────────────────
        blackmatter-clusterctl = cluster.clusterctl;
        blackmatter-talosctl = cluster.talosctl;
        blackmatter-vcluster = cluster.vcluster;
        blackmatter-crossplane-cli = cluster.crossplane-cli;
        blackmatter-kompose = cluster.kompose;
        blackmatter-kwok = cluster.kwok;
        blackmatter-velero = cluster.velero;

        # ── GitOps & CD ─────────────────────────────────────────────
        blackmatter-argocd = gitops.argocd;
        blackmatter-tektoncd-cli = gitops.tektoncd-cli;
        blackmatter-argo-rollouts = gitops.argo-rollouts;
        blackmatter-timoni = gitops.timoni;
        blackmatter-kapp = gitops.kapp;

        # ── kubectl plugins ─────────────────────────────────────────
        blackmatter-popeye = plugins.popeye;
        blackmatter-kubent = plugins.kubent;
        blackmatter-pluto = plugins.pluto;
        blackmatter-kor = plugins.kor;
        blackmatter-kube-capacity = plugins.kube-capacity;
        blackmatter-kubectl-neat = plugins.kubectl-neat;
        blackmatter-kubectl-images = plugins.kubectl-images;
        blackmatter-krew = plugins.krew;
        blackmatter-kubectl-ktop = plugins.kubectl-ktop;
        blackmatter-kubeshark = plugins.kubeshark;
        blackmatter-kubectl-cnpg = plugins.kubectl-cnpg;
        blackmatter-kubevirt = plugins.kubevirt;

        # ── Observability & monitoring ──────────────────────────────
        blackmatter-thanos = observability.thanos;
        blackmatter-logcli = observability.logcli;
        blackmatter-tempo-cli = observability.tempo-cli;
        blackmatter-mimirtool = observability.mimirtool;
        blackmatter-victoriametrics = observability.victoriametrics;
        blackmatter-coredns = observability.coredns;
        blackmatter-consul = observability.consul;
        blackmatter-kube-state-metrics = observability.kube-state-metrics;

        # ── Load testing & benchmarking ─────────────────────────────
        blackmatter-k6 = testing.k6;
        blackmatter-vegeta = testing.vegeta;
        blackmatter-hey = testing.hey;
        blackmatter-fortio = testing.fortio;

        # ── Cluster profile package sets (Linux-only) ─────────────────
        # Each profile bundles k3s + all extra tools it needs.
        # e.g. blackmatter-k3s-profile-cilium-standard = buildEnv { k3s, cilium-cli, hubble }
      } // (nixpkgs.lib.mapAttrs' (name: profile:
        nixpkgs.lib.nameValuePair "blackmatter-k3s-profile-${name}" (final.buildEnv {
          name = "k3s-profile-${name}";
          paths = resolveProfilePackages final name;
        })
      ) profileDefs.profiles))
    ];

    # ── Packages ──────────────────────────────────────────────────────
    # Cross-platform tools (kubectl, helm, k9s, etc.)
    packages = forEachSystem ({ pkgs, system, ... }: {
      default = pkgs.blackmatter-kubectl;

      # ── Core CLI tools (cross-platform) ───────────────────────────
      kubectl = pkgs.blackmatter-kubectl;
      helm = pkgs.blackmatter-helm;
      k9s = pkgs.blackmatter-k9s;
      fluxcd = pkgs.blackmatter-fluxcd;
      kubectx = pkgs.blackmatter-kubectx;
      stern = pkgs.blackmatter-stern;
      kubecolor = pkgs.blackmatter-kubecolor;
      kube-score = pkgs.blackmatter-kube-score;
      kubectl-tree = pkgs.blackmatter-kubectl-tree;
      kustomize = pkgs.blackmatter-kustomize;
      cilium-cli = pkgs.blackmatter-cilium-cli;

      # Container/image tools (cross-platform)
      crane = pkgs.blackmatter-crane;
      ko = pkgs.blackmatter-ko;

      # Helm ecosystem (cross-platform)
      helmfile = pkgs.blackmatter-helmfile;
      helm-diff = pkgs.blackmatter-helm-diff;
      helm-docs = pkgs.blackmatter-helm-docs;

      # Service mesh CLIs (cross-platform)
      istioctl = pkgs.blackmatter-istioctl;
      linkerd = pkgs.blackmatter-linkerd;
      hubble = pkgs.blackmatter-hubble;
      cmctl = pkgs.blackmatter-cmctl;

      # Security (cross-platform)
      kubeseal = pkgs.blackmatter-kubeseal;
      trivy = pkgs.blackmatter-trivy;
      grype = pkgs.blackmatter-grype;
      cosign = pkgs.blackmatter-cosign;
      kyverno = pkgs.blackmatter-kyverno;
      open-policy-agent = pkgs.blackmatter-open-policy-agent;
      conftest = pkgs.blackmatter-conftest;
      falcoctl = pkgs.blackmatter-falcoctl;
      kubescape = pkgs.blackmatter-kubescape;
      kube-linter = pkgs.blackmatter-kube-linter;
      kubeconform = pkgs.blackmatter-kubeconform;
      step-cli = pkgs.blackmatter-step-cli;

      # Cluster management (cross-platform)
      clusterctl = pkgs.blackmatter-clusterctl;
      talosctl = pkgs.blackmatter-talosctl;
      vcluster = pkgs.blackmatter-vcluster;
      crossplane-cli = pkgs.blackmatter-crossplane-cli;
      kompose = pkgs.blackmatter-kompose;
      kwok = pkgs.blackmatter-kwok;
      velero = pkgs.blackmatter-velero;

      # GitOps & CD (cross-platform)
      argocd = pkgs.blackmatter-argocd;
      tektoncd-cli = pkgs.blackmatter-tektoncd-cli;
      argo-rollouts = pkgs.blackmatter-argo-rollouts;
      timoni = pkgs.blackmatter-timoni;
      kapp = pkgs.blackmatter-kapp;

      # kubectl plugins (cross-platform)
      popeye = pkgs.blackmatter-popeye;
      kubent = pkgs.blackmatter-kubent;
      pluto = pkgs.blackmatter-pluto;
      kor = pkgs.blackmatter-kor;
      kube-capacity = pkgs.blackmatter-kube-capacity;
      kubectl-neat = pkgs.blackmatter-kubectl-neat;
      kubectl-images = pkgs.blackmatter-kubectl-images;
      krew = pkgs.blackmatter-krew;
      kubectl-ktop = pkgs.blackmatter-kubectl-ktop;
      kubeshark = pkgs.blackmatter-kubeshark;
      kubectl-cnpg = pkgs.blackmatter-kubectl-cnpg;
      kubevirt = pkgs.blackmatter-kubevirt;

      # Observability (cross-platform)
      thanos = pkgs.blackmatter-thanos;
      logcli = pkgs.blackmatter-logcli;
      tempo-cli = pkgs.blackmatter-tempo-cli;
      mimirtool = pkgs.blackmatter-mimirtool;
      coredns = pkgs.blackmatter-coredns;
      consul = pkgs.blackmatter-consul;
      kube-state-metrics = pkgs.blackmatter-kube-state-metrics;

      # Load testing (cross-platform)
      k6 = pkgs.blackmatter-k6;
      vegeta = pkgs.blackmatter-vegeta;
      hey = pkgs.blackmatter-hey;
      fortio = pkgs.blackmatter-fortio;

      # Development frameworks (cross-platform)
      kubebuilder = pkgs.blackmatter-kubebuilder;
      operator-sdk = pkgs.blackmatter-operator-sdk;
      etcd = pkgs.blackmatter-etcd;
    }
    # Linux-only packages
    // nixpkgs.lib.optionalAttrs (builtins.elem system linuxSystems) {
      k3s = pkgs.blackmatter-k3s;
      k3s-latest = pkgs.blackmatter-k3s-latest;
      calicoctl = pkgs.blackmatter-calicoctl;

      # Container runtime tools (Linux-only)
      nerdctl = pkgs.blackmatter-nerdctl;
      buildkit = pkgs.blackmatter-buildkit;

      # VictoriaMetrics (Linux-only due to complex patches)
      victoriametrics = pkgs.blackmatter-victoriametrics;

      # Network plugins (Linux-only)
      cni-plugins = pkgs.blackmatter-cni-plugins;
      flannel = pkgs.blackmatter-flannel;
      cni-plugin-flannel = pkgs.blackmatter-cni-plugin-flannel;
      multus-cni = pkgs.blackmatter-multus-cni;
      calico-cni-plugin = pkgs.blackmatter-calico-cni-plugin;
      calico-apiserver = pkgs.blackmatter-calico-apiserver;
      calico-typha = pkgs.blackmatter-calico-typha;
      calico-kube-controllers = pkgs.blackmatter-calico-kube-controllers;
      calico-pod2daemon = pkgs.blackmatter-calico-pod2daemon;
      confd-calico = pkgs.blackmatter-confd-calico;
    }
    # Profile package sets (Linux-only — contain k3s + extra tools)
    // nixpkgs.lib.optionalAttrs (builtins.elem system linuxSystems)
      (nixpkgs.lib.mapAttrs' (name: _:
        nixpkgs.lib.nameValuePair "profile-${name}" pkgs.${"blackmatter-k3s-profile-${name}"}
      ) profileDefs.profiles));

    # ── Tests ───────────────────────────────────────────────────────
    # Unit tests: nix eval .#tests.x86_64-linux.unit
    tests = forEachLinuxSystem ({ pkgs, ... }: {
      unit = import ./tests/unit {
        lib = nixpkgs.lib;
        inherit nixosHelpers;
      };
      hm-module = import ./tests/unit/hm-module.nix {
        lib = nixpkgs.lib;
      };
    });

    # Integration tests (VM-based, x86_64-linux only)
    # nix build .#checks.x86_64-linux.single-node
    checks.x86_64-linux = let
      system = "x86_64-linux";
      pkgs = mkPkgs system;
      k3sPackage = pkgs.blackmatter-k3s;
      k3sPackageLatest = pkgs.blackmatter-k3s-latest;
    in {
      # 1.34 (default track)
      single-node = import ./tests/integration/single-node.nix {
        inherit pkgs k3sModule k3sPackage;
        lib = nixpkgs.lib;
      };
      multi-node = import ./tests/integration/multi-node.nix {
        inherit pkgs k3sModule k3sPackage;
        lib = nixpkgs.lib;
      };
      ha-server = import ./tests/integration/ha-server.nix {
        inherit pkgs k3sModule k3sPackage;
        lib = nixpkgs.lib;
      };
      # 1.35 (latest track)
      single-node-latest = import ./tests/integration/single-node.nix {
        inherit pkgs k3sModule;
        k3sPackage = k3sPackageLatest;
        lib = nixpkgs.lib;
      };
      multi-node-latest = import ./tests/integration/multi-node.nix {
        inherit pkgs k3sModule;
        k3sPackage = k3sPackageLatest;
        lib = nixpkgs.lib;
      };
      ha-server-latest = import ./tests/integration/ha-server.nix {
        inherit pkgs k3sModule;
        k3sPackage = k3sPackageLatest;
        lib = nixpkgs.lib;
      };

      # Profile integration tests (flannel-minimal is cheapest to test)
      single-node-flannel-minimal = import ./tests/integration/single-node.nix {
        inherit pkgs k3sModule k3sPackage;
        lib = nixpkgs.lib;
        profile = "flannel-minimal";
      };
      single-node-flannel-minimal-latest = import ./tests/integration/single-node.nix {
        inherit pkgs k3sModule;
        k3sPackage = k3sPackageLatest;
        lib = nixpkgs.lib;
        profile = "flannel-minimal";
      };

      # Profile evaluation checks — verify every profile × distribution evaluates
      profile-eval = let
        evalProfile = profileName: let
          mod = k3sModule;
          evaluated = nixpkgs.lib.evalModules {
            modules = [
              mod
              {
                config.services.blackmatter.k3s = {
                  enable = true;
                  profile = profileName;
                };
              }
              {
                options = {
                  systemd.services = nixpkgs.lib.mkOption { type = nixpkgs.lib.types.attrs; default = {}; };
                  systemd.tmpfiles.rules = nixpkgs.lib.mkOption { type = nixpkgs.lib.types.listOf nixpkgs.lib.types.str; default = []; };
                  networking.firewall = nixpkgs.lib.mkOption { type = nixpkgs.lib.types.attrs; default = {}; };
                  boot.kernelModules = nixpkgs.lib.mkOption { type = nixpkgs.lib.types.listOf nixpkgs.lib.types.str; default = []; };
                  boot.kernel.sysctl = nixpkgs.lib.mkOption { type = nixpkgs.lib.types.attrs; default = {}; };
                  environment.systemPackages = nixpkgs.lib.mkOption { type = nixpkgs.lib.types.listOf nixpkgs.lib.types.package; default = []; };
                  environment.shellAliases = nixpkgs.lib.mkOption { type = nixpkgs.lib.types.attrs; default = {}; };
                  assertions = nixpkgs.lib.mkOption { type = nixpkgs.lib.types.listOf nixpkgs.lib.types.attrs; default = []; };
                };
              }
            ];
          };
        in evaluated.config.services.blackmatter.k3s.profile == profileName;
        allPass = nixpkgs.lib.all (name: evalProfile name) (nixpkgs.lib.attrNames profileDefs.profiles);
      in pkgs.runCommand "profile-eval-check" {} (
        if allPass
        then "echo 'All ${toString (nixpkgs.lib.length (nixpkgs.lib.attrNames profileDefs.profiles))} profiles evaluate successfully' > $out"
        else builtins.throw "Profile evaluation failed"
      );
    };
  };
}
