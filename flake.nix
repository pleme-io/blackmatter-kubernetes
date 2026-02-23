{
  description = "Blackmatter Kubernetes - K8s tools, K9s TUI, K3d, k3s, vanilla k8s, and cluster management";

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
    # k3s + k8s + tools are Linux-only; HM modules are cross-platform
    linuxSystems = [ "x86_64-linux" "aarch64-linux" ];

    # Cross-platform systems (for tools that work on macOS too)
    allSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

    # Go overlay — builds Go from upstream source via blackmatter-go
    goOverlay = (import "${blackmatter-go}/lib/overlay.nix").mkGoOverlay {};

    # Go tool builder from blackmatter-go
    goToolBuilder = import "${blackmatter-go}/lib/tool.nix";
    mkGoTool = goToolBuilder.mkGoTool;

    # Go monorepo source factory from substrate
    mkGoMonorepoSource = (import "${substrate}/lib/go-monorepo.nix").mkGoMonorepoSource;

    # Go monorepo binary builder from substrate
    mkGoMonorepoBinary = (import "${substrate}/lib/go-monorepo-binary.nix").mkGoMonorepoBinary;

    # Versioned overlay generator from substrate
    mkVersionedOverlay = (import "${substrate}/lib/versioned-overlay.nix").mkVersionedOverlay;

    # Test helpers from substrate
    testHelpers = import "${substrate}/lib/test-helpers.nix" { lib = nixpkgs.lib; };

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
    k8sModule = self.nixosModules.kubernetes;

    # Profile definitions (pure data)
    profileDefs = import ./lib/profiles.nix { lib = nixpkgs.lib; };

    # Map profile extraPackages names to overlay package names (k3s)
    resolveK3sProfilePackages = pkgs: profileName: let
      profile = profileDefs.profiles.${profileName};
      resolve = name: pkgs.${"blackmatter-${name}"};
    in [ (pkgs.blackmatter-k3s or pkgs.k3s) ] ++ map resolve profile.extraPackages;

    # All supported tracks
    allTracks = [ "1.30" "1.31" "1.32" "1.33" "1.34" "1.35" ];

    # Map profile extraPackages names to overlay package names (vanilla k8s)
    resolveK8sProfilePackages = pkgs: profileName: let
      profile = profileDefs.profiles.${profileName};
      resolve = name: pkgs.${"blackmatter-${name}"};
      k8sPkgs = import ./pkgs/kubernetes { inherit pkgs mkGoMonorepoSource mkGoMonorepoBinary; };
    in with k8sPkgs; [
      kubelet_1_34
      kubeadm_1_34
      kube-apiserver_1_34
      kube-controller-manager_1_34
      kube-scheduler_1_34
      kube-proxy_1_34
    ] ++ map resolve profile.extraPackages;

    # ── Overlay helpers ─────────────────────────────────────────────────
    # Auto-prefix all attrs from a category with "blackmatter-"
    prefixAll = attrset:
      nixpkgs.lib.mapAttrs' (name: value:
        nixpkgs.lib.nameValuePair "blackmatter-${name}" value
      ) attrset;

    # ── Package list declarations ────────────────────────────────────────
    # Cross-platform tools (available on macOS + Linux)
    crossPlatformTools = [
      # Core CLI
      "kubectl" "helm" "k9s" "fluxcd" "kubectx" "stern" "kubecolor"
      "kube-score" "kubectl-tree" "kustomize" "cilium-cli"
      # Container/image
      "crane" "ko"
      # Helm ecosystem
      "helmfile" "helm-diff" "helm-docs"
      # Service mesh CLIs
      "istioctl" "linkerd" "hubble" "cmctl"
      # Security
      "kubeseal" "trivy" "grype" "cosign" "kyverno" "open-policy-agent"
      "conftest" "falcoctl" "kubescape" "kube-linter" "kubeconform" "step-cli"
      # Cluster management
      "clusterctl" "talosctl" "vcluster" "crossplane-cli" "kompose" "kwok" "velero"
      # GitOps & CD
      "argocd" "tektoncd-cli" "argo-rollouts" "timoni" "kapp"
      # kubectl plugins
      "popeye" "kubent" "pluto" "kor" "kube-capacity" "kubectl-neat"
      "kubectl-images" "krew" "kubectl-ktop" "kubeshark" "kubectl-cnpg" "kubevirt"
      # Observability
      "thanos" "logcli" "tempo-cli" "mimirtool" "coredns" "consul"
      "kube-state-metrics"
      # Load testing
      "k6" "vegeta" "hey" "fortio"
      # Development
      "kubebuilder" "operator-sdk" "etcd"
    ];

    # Linux-only tools (k3s, network plugins, runtime components)
    linuxOnlyTools = [
      "k3s" "k3s-latest"
      "calicoctl"
      # Vanilla Kubernetes default + latest
      "kubectl-latest"
      "kubelet" "kubelet-latest"
      "kubeadm" "kubeadm-latest"
      "kube-apiserver" "kube-apiserver-latest"
      "kube-controller-manager" "kube-controller-manager-latest"
      "kube-scheduler" "kube-scheduler-latest"
      "kube-proxy" "kube-proxy-latest"
      "etcd-server" "etcd-server-latest"
      "containerd" "containerd-latest"
      "runc" "runc-latest"
      "k8s-cni-plugins" "k8s-cni-plugins-latest"
      "crictl" "crictl-latest"
      # Container runtime tools
      "nerdctl" "buildkit"
      # VictoriaMetrics
      "victoriametrics"
      # Network plugins
      "cni-plugins" "flannel" "cni-plugin-flannel" "multus-cni"
      "calico-cni-plugin" "calico-apiserver" "calico-typha"
      "calico-kube-controllers" "calico-pod2daemon" "confd-calico"
    ];

    # Versioned k8s component names (for per-track package generation)
    k8sVersionedComponents = [
      "kubectl" "kubelet" "kubeadm" "kube-apiserver" "kube-controller-manager"
      "kube-scheduler" "kube-proxy" "etcd-server" "containerd"
      "runc" "k8s-cni-plugins" "crictl"
    ];

  in {
    # ── Home-manager modules (cross-platform) ───────────────────────
    homeManagerModules.default = import ./module/home-manager;

    # ── NixOS modules (Linux-only) ──────────────────────────────────
    nixosModules.k3s = import ./module/nixos/k3s { inherit nixosHelpers; };
    nixosModules.kubectl = import ./module/nixos/kubectl;
    nixosModules.fluxcd = import ./module/nixos/fluxcd { inherit nixosHelpers; };
    nixosModules.kubernetes = import ./module/nixos/kubernetes { inherit nixosHelpers mkGoMonorepoSource mkGoMonorepoBinary; };

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
        k8sPkgs = import ./pkgs/kubernetes { pkgs = final; inherit mkGoMonorepoSource mkGoMonorepoBinary; };
        k3sPkgs = import ./pkgs/k3s { inherit (final) lib callPackage; };

        # Generate versioned overlay entries + default/latest aliases
        k3sOverlayEntries = mkVersionedOverlay {
          lib = nixpkgs.lib;
          tracks = allTracks;
          defaultTrack = "1.34";
          latestTrack = "1.35";
          components = {
            k3s = { src = k3sPkgs; srcAttr = s: "k3s_${s}"; };
          };
        };
        k8sOverlayEntries = mkVersionedOverlay {
          lib = nixpkgs.lib;
          tracks = allTracks;
          defaultTrack = "1.34";
          latestTrack = "1.35";
          components = {
            kubectl     = { src = k8sPkgs; };
            kubelet      = { src = k8sPkgs; };
            kubeadm      = { src = k8sPkgs; };
            kube-apiserver = { src = k8sPkgs; };
            kube-controller-manager = { src = k8sPkgs; };
            kube-scheduler = { src = k8sPkgs; };
            kube-proxy   = { src = k8sPkgs; };
            etcd         = { src = k8sPkgs; overlayName = "etcd-server"; };
            containerd   = { src = k8sPkgs; };
            runc         = { src = k8sPkgs; };
            cni-plugins  = { src = k8sPkgs; overlayName = "k8s-cni-plugins"; };
            crictl       = { src = k8sPkgs; };
          };
        };
      in k3sOverlayEntries // k8sOverlayEntries

      # ── Auto-prefixed category packages ──────────────────────────
      // prefixAll tools
      // prefixAll network
      // prefixAll security
      // prefixAll cluster
      // prefixAll gitops
      // prefixAll plugins
      // prefixAll observability
      // prefixAll testing

      # ── k3s profile package sets (Linux-only) ───────────────────
      // (nixpkgs.lib.mapAttrs' (name: profile:
        nixpkgs.lib.nameValuePair "blackmatter-k3s-profile-${name}" (final.buildEnv {
          name = "k3s-profile-${name}";
          paths = resolveK3sProfilePackages final name;
        })
      ) profileDefs.profiles)

      # ── k8s profile package sets (Linux-only) ───────────────────
      // (nixpkgs.lib.mapAttrs' (name: profile:
        nixpkgs.lib.nameValuePair "blackmatter-k8s-profile-${name}" (final.buildEnv {
          name = "k8s-profile-${name}";
          paths = resolveK8sProfilePackages final name;
        })
      ) profileDefs.profiles))
    ];

    # ── Packages ──────────────────────────────────────────────────────
    packages = forEachSystem ({ pkgs, system, ... }: let
      lib = nixpkgs.lib;
      isLinux = builtins.elem system linuxSystems;

      # Generate package entries from overlay: shortname → pkgs.blackmatter-shortname
      mkPkgsFrom = names: lib.genAttrs names (n: pkgs.${"blackmatter-${n}"});

      # Generate versioned package entries: name-1-30 → pkgs.blackmatter-name-1-30
      mkVersionedPkgs = comps: lib.listToAttrs (lib.concatMap (track: let
        suffix = builtins.replaceStrings ["."] ["-"] track;
      in map (name: {
        name = "${name}-${suffix}";
        value = pkgs.${"blackmatter-${name}-${suffix}"};
      }) comps) allTracks);

    in { default = pkgs.blackmatter-kubectl; }
    // mkPkgsFrom crossPlatformTools
    // lib.optionalAttrs isLinux (mkPkgsFrom linuxOnlyTools)
    // lib.optionalAttrs isLinux (
      mkVersionedPkgs [ "k3s" ] // mkVersionedPkgs k8sVersionedComponents)
    // lib.optionalAttrs isLinux (
      (lib.mapAttrs' (name: _:
        lib.nameValuePair "k3s-profile-${name}" pkgs.${"blackmatter-k3s-profile-${name}"}
      ) profileDefs.profiles)
      // (lib.mapAttrs' (name: _:
        lib.nameValuePair "k8s-profile-${name}" pkgs.${"blackmatter-k8s-profile-${name}"}
      ) profileDefs.profiles)));

    # ── Tests ───────────────────────────────────────────────────────
    # Unit tests: nix eval .#tests.x86_64-linux.unit
    tests = forEachLinuxSystem ({ pkgs, ... }: {
      unit = import ./tests/unit {
        lib = nixpkgs.lib;
        inherit nixosHelpers testHelpers mkGoMonorepoSource mkGoMonorepoBinary mkVersionedOverlay;
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
      # ── k3s tests ────────────────────────────────────────────────
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

      # ── k8s tests ────────────────────────────────────────────────
      k8s-single-node = import ./tests/integration/k8s-single-node.nix {
        inherit pkgs k8sModule;
        lib = nixpkgs.lib;
      };
      k8s-single-node-latest = import ./tests/integration/k8s-single-node.nix {
        inherit pkgs k8sModule;
        lib = nixpkgs.lib;
      };
      k8s-single-node-flannel-minimal = import ./tests/integration/k8s-single-node.nix {
        inherit pkgs k8sModule;
        lib = nixpkgs.lib;
        profile = "flannel-minimal";
      };

      # ── Profile evaluation checks (using substrate test helpers) ───
      k8s-profile-eval = testHelpers.mkProfileEvalCheck {
        inherit pkgs;
        name = "k8s-profile-eval-check";
        module = k8sModule;
        profiles = profileDefs.profiles;
        configPath = ["services" "blackmatter" "kubernetes"];
        mkConfig = profileName: { enable = false; profile = profileName; };
      };

      profile-eval = testHelpers.mkProfileEvalCheck {
        inherit pkgs;
        name = "k3s-profile-eval-check";
        module = k3sModule;
        profiles = profileDefs.profiles;
        configPath = ["services" "blackmatter" "k3s"];
        mkConfig = profileName: { enable = true; profile = profileName; };
      };
    };
  };
}
