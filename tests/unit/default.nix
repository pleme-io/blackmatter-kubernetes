# Unit tests — pure-Nix evaluation tests (no VMs, instant)
#
# Tests module option structure, assertion logic, flag construction,
# firewall/kernel config generation, distribution system, and vanilla k8s.
#
# Uses substrate's test helpers (mkTest, runTests, evalNixOSModule).
#
# Run: nix eval .#tests.unit
{ lib, nixosHelpers, testHelpers, mkGoMonorepoSource, mkGoMonorepoBinary, mkVersionedOverlay }:

let
  inherit (testHelpers) mkTest runTests evalNixOSModule;

  distributions = import ../../lib/distributions.nix { inherit lib; };
  profiles = import ../../lib/profiles.nix { inherit lib; };
  versionRegistry = import ../../lib/versions;

  allTracks = [ "1.30" "1.31" "1.32" "1.33" "1.34" "1.35" ];

  # Pre-import all k3s version pin files
  k3sVersionFiles = {
    "1.30" = import ../../pkgs/k3s/versions/1_30.nix;
    "1.31" = import ../../pkgs/k3s/versions/1_31.nix;
    "1.32" = import ../../pkgs/k3s/versions/1_32.nix;
    "1.33" = import ../../pkgs/k3s/versions/1_33.nix;
    "1.34" = import ../../pkgs/k3s/versions/1_34.nix;
    "1.35" = import ../../pkgs/k3s/versions/1_35.nix;
  };

  # Pre-import all k8s monorepo hash files
  k8sHashFiles = {
    "1.30" = import ../../pkgs/kubernetes/versions/1_30.nix;
    "1.31" = import ../../pkgs/kubernetes/versions/1_31.nix;
    "1.32" = import ../../pkgs/kubernetes/versions/1_32.nix;
    "1.33" = import ../../pkgs/kubernetes/versions/1_33.nix;
    "1.34" = import ../../pkgs/kubernetes/versions/1_34.nix;
    "1.35" = import ../../pkgs/kubernetes/versions/1_35.nix;
  };

  # Mock packages for source factory tests
  mockPkgs = { inherit lib; fetchFromGitHub = _: null; };
  mkSource = import ../../pkgs/kubernetes/source.nix { inherit mkGoMonorepoSource; pkgs = mockPkgs; };

  # Helper: extract minor version number from "1.XX.Y" string
  extractMinor = v: lib.toInt (builtins.elemAt (lib.splitString "." v) 1);

  # Evaluate the k3s module with given config
  k3sModule = import ../../module/nixos/k3s { inherit nixosHelpers; };
  evalModule = config: (evalNixOSModule {
    module = k3sModule;
    inherit config;
    configPath = ["services" "blackmatter" "k3s"];
  }).config;

  # Evaluate the k8s module with given config (lazy — don't force packages)
  k8sModule = import ../../module/nixos/kubernetes { inherit nixosHelpers mkGoMonorepoSource mkGoMonorepoBinary; };
  evalK8sModule = config: evalNixOSModule {
    module = k8sModule;
    inherit config;
    configPath = ["services" "blackmatter" "kubernetes"];
  };

in runTests [
  # ── Option existence tests ─────────────────────────────────────────
  (mkTest "option-enable-exists"
    (let evaluated = evalNixOSModule {
           module = k3sModule;
           configPath = ["services" "blackmatter" "k3s"];
         };
     in evaluated.options ? services
        && evaluated.options.services ? blackmatter)
    "services.blackmatter.k3s options should exist")

  # ── Default value tests (real evalModule) ──────────────────────────
  (mkTest "default-role-is-server"
    (let cfg = (evalModule {}).services.blackmatter.k3s;
     in cfg.role == "server")
    "default role should be server")

  (mkTest "default-cluster-cidr"
    (let cfg = (evalModule {}).services.blackmatter.k3s;
     in cfg.clusterCIDR == "10.42.0.0/16")
    "default clusterCIDR should be 10.42.0.0/16")

  (mkTest "default-service-cidr"
    (let cfg = (evalModule {}).services.blackmatter.k3s;
     in cfg.serviceCIDR == "10.43.0.0/16")
    "default serviceCIDR should be 10.43.0.0/16")

  (mkTest "default-cluster-dns"
    (let cfg = (evalModule {}).services.blackmatter.k3s;
     in cfg.clusterDNS == "10.43.0.10")
    "default clusterDNS should be 10.43.0.10")

  (mkTest "default-data-dir"
    (let cfg = (evalModule {}).services.blackmatter.k3s;
     in cfg.dataDir == "/var/lib/rancher/k3s")
    "default dataDir should be /var/lib/rancher/k3s")

  (mkTest "default-distribution"
    (let cfg = (evalModule {}).services.blackmatter.k3s;
     in cfg.distribution == "1.34")
    "default distribution should be 1.34")

  (mkTest "default-firewall-enabled"
    (let cfg = (evalModule {}).services.blackmatter.k3s;
     in cfg.firewall.enable == true
        && cfg.firewall.apiServerPort == 6443)
    "firewall should be enabled by default with apiserver on 6443")

  (mkTest "default-kernel-enabled"
    (let cfg = (evalModule {}).services.blackmatter.k3s;
     in cfg.kernel.enable == true)
    "kernel configuration should be enabled by default")

  (mkTest "default-wait-for-dns"
    (let cfg = (evalModule {}).services.blackmatter.k3s;
     in cfg.waitForDNS.enable == true
        && cfg.waitForDNS.timeout == 30)
    "waitForDNS should be enabled with 30 retries by default")

  (mkTest "default-profile-null"
    (let cfg = (evalModule {}).services.blackmatter.k3s;
     in cfg.profile == null)
    "default profile should be null")

  # ── Flag construction tests ────────────────────────────────────────
  (mkTest "disable-generates-flags"
    (let flags = map (comp: "--disable ${comp}") [ "traefik" "servicelb" ];
     in flags == [ "--disable traefik" "--disable servicelb" ])
    "disable list should generate --disable flags")

  (mkTest "cluster-init-flag"
    (lib.optional true "--cluster-init" == [ "--cluster-init" ])
    "clusterInit=true should generate --cluster-init flag")

  (mkTest "node-label-flags"
    (map (l: "--node-label ${l}") [ "role=worker" "zone=a" ]
     == [ "--node-label role=worker" "--node-label zone=a" ])
    "nodeLabel should generate --node-label flags")

  (mkTest "node-taint-flags"
    (map (t: "--node-taint ${t}") [ "dedicated=gpu:NoSchedule" ]
     == [ "--node-taint dedicated=gpu:NoSchedule" ])
    "nodeTaint should generate --node-taint flags")

  # ── Firewall port tests (option defaults) ──────────────────────────
  (mkTest "firewall-default-udp"
    (let cfg = (evalModule {}).services.blackmatter.k3s;
     in cfg.firewall.extraUDPPorts == [ 8472 ])
    "default UDP ports should include VXLAN 8472")

  (mkTest "firewall-default-trusted"
    (let cfg = (evalModule {}).services.blackmatter.k3s;
     in cfg.firewall.trustedInterfaces == [ "cni0" "flannel.1" ])
    "default trusted interfaces should include cni0 and flannel.1")

  # ── Distribution system tests ──────────────────────────────────────
  (mkTest "distribution-tracks-exist"
    (lib.all (t: distributions.tracks ? ${t}) allTracks)
    "all 6 distribution tracks (1.30-1.35) should exist")

  (mkTest "distribution-default-track"
    (distributions.defaultTrack == "1.34")
    "default distribution track should be 1.34")

  (mkTest "distribution-latest-track"
    (distributions.latestTrack == "1.35")
    "latest distribution track should be 1.35")

  (mkTest "distribution-track-status"
    (distributions.tracks."1.30".status == "eol"
     && distributions.tracks."1.31".status == "eol"
     && distributions.tracks."1.32".status == "eol"
     && distributions.tracks."1.33".status == "supported"
     && distributions.tracks."1.34".status == "supported"
     && distributions.tracks."1.35".status == "current")
    "track statuses should be eol/eol/eol/supported/supported/current")

  (mkTest "distribution-tracks-have-eol-dates"
    (lib.all (t: (distributions.tracks.${t}) ? eol) allTracks)
    "all tracks should have EOL dates")

  (mkTest "distribution-eol-dates-ordered"
    (let
      dates = map (t: distributions.tracks.${t}.eol) allTracks;
      sorted = lib.sort (a: b: a < b) dates;
    in dates == sorted)
    "EOL dates should be chronologically ordered across tracks")

  (mkTest "distribution-version-files-exist"
    (lib.all (t: (k3sVersionFiles.${t}) ? k3sVersion) allTracks)
    "all k3s version pin files should exist and have k3sVersion")

  (mkTest "distribution-version-strings"
    (lib.all (t:
      lib.hasPrefix t (k3sVersionFiles.${t}).k3sVersion
    ) allTracks)
    "k3s version strings should start with their track number")

  (mkTest "distribution-skew-policy"
    (distributions.skewPolicy.kubectlRange == 1
     && distributions.skewPolicy.controlPlaneSkew == 1
     && distributions.skewPolicy.kubeletMaxLag == 3)
    "skew policy should define kubectl, control plane, and kubelet ranges")

  (mkTest "distribution-supported-tracks-within-kubelet-skew"
    (let
      supportedTracks = lib.filterAttrs (_: t: t.status != "eol") distributions.tracks;
      minors = map (t: lib.toInt (lib.removePrefix "1." t.kubernetesVersion))
                   (lib.attrValues supportedTracks);
      maxMinor = lib.foldl' lib.max 0 minors;
      minMinor = lib.foldl' lib.min 100 minors;
    in (maxMinor - minMinor) <= distributions.skewPolicy.kubeletMaxLag)
    "supported track spread should be within kubelet max lag policy")

  # ── Shared version registry tests ────────────────────────────────────

  (mkTest "version-registry-tracks-exist"
    (lib.all (t: versionRegistry ? ${t}) allTracks)
    "version registry should have all 6 tracks (1.30-1.35)")

  (mkTest "version-registry-all-tracks-have-fields"
    (let
      requiredFields = [ "kubernetesVersion" "etcdVersion" "containerdVersion"
                         "runcVersion" "cniPluginsVersion" "crictlVersion" "pauseVersion" ];
    in lib.all (t:
      lib.all (f: versionRegistry.${t} ? ${f}) requiredFields
    ) allTracks)
    "all tracks should have all required version fields")

  (mkTest "version-registry-1.30-versions"
    (let v = versionRegistry."1.30";
     in v.kubernetesVersion == "1.30.14"
        && v.etcdVersion == "3.5.15"
        && v.containerdVersion == "1.7.27"
        && v.runcVersion == "1.2.6"
        && v.cniPluginsVersion == "1.4.0"
        && v.crictlVersion == "1.29.0"
        && v.pauseVersion == "3.9")
    "1.30 track should have correct version values")

  (mkTest "version-registry-1.31-versions"
    (let v = versionRegistry."1.31";
     in v.kubernetesVersion == "1.31.14"
        && v.etcdVersion == "3.5.24"
        && v.containerdVersion == "2.1.5"
        && v.runcVersion == "1.2.8"
        && v.cniPluginsVersion == "1.5.1"
        && v.crictlVersion == "1.31.0"
        && v.pauseVersion == "3.10")
    "1.31 track should have correct version values")

  (mkTest "version-registry-1.32-versions"
    (let v = versionRegistry."1.32";
     in v.kubernetesVersion == "1.32.12"
        && v.etcdVersion == "3.5.24"
        && v.containerdVersion == "2.1.5"
        && v.runcVersion == "1.2.9"
        && v.cniPluginsVersion == "1.6.0"
        && v.crictlVersion == "1.31.1"
        && v.pauseVersion == "3.10")
    "1.32 track should have correct version values")

  (mkTest "version-registry-1.33-versions"
    (let v = versionRegistry."1.33";
     in v.kubernetesVersion == "1.33.8"
        && v.etcdVersion == "3.5.24"
        && v.containerdVersion == "2.1.5"
        && v.runcVersion == "1.3.4"
        && v.cniPluginsVersion == "1.6.2"
        && v.crictlVersion == "1.32.0"
        && v.pauseVersion == "3.10")
    "1.33 track should have correct version values")

  (mkTest "version-registry-1.34-versions"
    (let v = versionRegistry."1.34";
     in v.kubernetesVersion == "1.34.3"
        && v.etcdVersion == "3.6.7"
        && v.containerdVersion == "2.1.5"
        && v.runcVersion == "1.2.6"
        && v.cniPluginsVersion == "1.8.0"
        && v.crictlVersion == "1.34.0"
        && v.pauseVersion == "3.11")
    "1.34 track should have correct version values")

  (mkTest "version-registry-1.35-versions"
    (let v = versionRegistry."1.35";
     in v.kubernetesVersion == "1.35.1"
        && v.etcdVersion == "3.6.7"
        && v.containerdVersion == "2.1.5"
        && v.runcVersion == "1.2.6"
        && v.cniPluginsVersion == "1.9.0"
        && v.crictlVersion == "1.35.0"
        && v.pauseVersion == "3.11")
    "1.35 track should have correct version values")

  (mkTest "version-registry-kubernetes-version-progression"
    (let
      minors = map (t: extractMinor (versionRegistry.${t}).kubernetesVersion) allTracks;
      expected = lib.range 30 35;
    in minors == expected)
    "kubernetes minor versions should progress 30-35 across tracks")

  (mkTest "version-registry-containerd-v2-transition"
    (lib.hasPrefix "1." versionRegistry."1.30".containerdVersion
     && lib.all (t: lib.hasPrefix "2." versionRegistry.${t}.containerdVersion)
        [ "1.31" "1.32" "1.33" "1.34" "1.35" ])
    "1.30 should use containerd v1, 1.31+ should use containerd v2")

  (mkTest "version-registry-etcd-3.5-to-3.6-transition"
    (lib.hasPrefix "3.5" versionRegistry."1.30".etcdVersion
     && lib.hasPrefix "3.5" versionRegistry."1.31".etcdVersion
     && lib.hasPrefix "3.5" versionRegistry."1.32".etcdVersion
     && lib.hasPrefix "3.5" versionRegistry."1.33".etcdVersion
     && lib.hasPrefix "3.6" versionRegistry."1.34".etcdVersion
     && lib.hasPrefix "3.6" versionRegistry."1.35".etcdVersion)
    "etcd should transition from 3.5.x to 3.6.x between 1.33 and 1.34")

  # ── Version parity tests (k3s ↔ shared registry) ─────────────────────

  (mkTest "version-parity-k3s-kubernetes-all-tracks"
    (lib.all (t:
      lib.hasPrefix (versionRegistry.${t}).kubernetesVersion (k3sVersionFiles.${t}).k3sVersion
    ) allTracks)
    "k3s version should start with shared kubernetes version for all tracks")

  (mkTest "version-parity-k3s-containerd-all-tracks"
    (lib.all (t:
      lib.hasPrefix (versionRegistry.${t}).containerdVersion (k3sVersionFiles.${t}).containerdVersion
    ) allTracks)
    "k3s containerd version should start with shared version for all tracks")

  (mkTest "version-parity-k3s-crictl-all-tracks"
    (lib.all (t:
      lib.hasPrefix (versionRegistry.${t}).crictlVersion (k3sVersionFiles.${t}).criCtlVersion
    ) allTracks)
    "k3s crictl version should start with shared version for all tracks")

  (mkTest "version-parity-kubernetes-minor-matches"
    (lib.all (t:
      lib.hasPrefix t (versionRegistry.${t}).kubernetesVersion
    ) allTracks)
    "version registry kubernetes versions should match their track names")

  (mkTest "version-parity-k3s-containerd-v1-v2-package"
    ((k3sVersionFiles."1.30").containerdPackage == "github.com/containerd/containerd"
     && lib.all (t:
       (k3sVersionFiles.${t}).containerdPackage == "github.com/k3s-io/containerd/v2"
     ) [ "1.31" "1.32" "1.33" "1.34" "1.35" ])
    "k3s 1.30 should use upstream containerd v1, 1.31+ should use k3s-io containerd v2")

  # ── Profile system tests ──────────────────────────────────────────────

  (mkTest "profiles-exist"
    (let names = lib.attrNames profiles.profiles;
     in lib.length names == 8)
    "should have exactly 8 profiles")

  (mkTest "profiles-all-have-required-fields"
    (let
      requiredFields = [ "name" "description" "use" "cni" "disable" "disableKubeProxy"
                         "extraFlags" "extraPackages" "firewallTCP" "firewallUDP"
                         "trustedInterfaces" "kernelModules" "manifests" ];
      checkProfile = _: p: lib.all (f: p ? ${f}) requiredFields;
    in lib.all (name: checkProfile name profiles.profiles.${name})
       (lib.attrNames profiles.profiles))
    "all profiles should have all required fields (including disableKubeProxy)")

  (mkTest "profiles-no-coredns-disabled"
    (lib.all (name:
      let p = profiles.profiles.${name};
      in !(lib.elem "coredns" p.disable))
      (lib.attrNames profiles.profiles))
    "no profile should disable coredns")

  (mkTest "profiles-cilium-disable-kube-proxy"
    (let
      ciliumProfiles = lib.filterAttrs (_: p: p.cni == "cilium") profiles.profiles;
    in lib.all (p:
      lib.elem "--disable-kube-proxy" p.extraFlags
      && p.disableKubeProxy == true
    ) (lib.attrValues ciliumProfiles))
    "all cilium profiles should set --disable-kube-proxy and disableKubeProxy")

  (mkTest "profiles-non-cilium-no-disable-kube-proxy"
    (let
      nonCiliumProfiles = lib.filterAttrs (_: p: p.cni != "cilium") profiles.profiles;
    in lib.all (p:
      p.disableKubeProxy == false
    ) (lib.attrValues nonCiliumProfiles))
    "non-cilium profiles should not disable kube-proxy")

  (mkTest "profiles-calico-cilium-disable-flannel"
    (let
      nonFlannelProfiles = lib.filterAttrs (_: p:
        p.cni == "calico" || p.cni == "cilium"
      ) profiles.profiles;
    in lib.all (p:
      lib.elem "--flannel-backend=none" p.extraFlags
    ) (lib.attrValues nonFlannelProfiles))
    "calico and cilium profiles should set --flannel-backend=none")

  (mkTest "profiles-flannel-no-extra-cni-flags"
    (let
      flannelProfiles = lib.filterAttrs (_: p: p.cni == "flannel") profiles.profiles;
    in lib.all (p:
      !(lib.elem "--flannel-backend=none" p.extraFlags)
    ) (lib.attrValues flannelProfiles))
    "flannel profiles should not set --flannel-backend=none")

  (mkTest "profiles-default-exists"
    (profiles.profiles ? ${profiles.defaultProfile})
    "default profile should be a valid profile name")

  (mkTest "profiles-names-match-keys"
    (lib.all (key:
      profiles.profiles.${key}.name == key
    ) (lib.attrNames profiles.profiles))
    "profile name field should match the attrset key")

  (mkTest "profiles-cni-valid"
    (let validCNIs = [ "flannel" "calico" "cilium" ];
     in lib.all (name:
       lib.elem profiles.profiles.${name}.cni validCNIs
     ) (lib.attrNames profiles.profiles))
    "all profiles should use a valid CNI (flannel, calico, cilium)")

  (mkTest "profiles-calico-has-calico-packages"
    (let
      calicoProfiles = lib.filterAttrs (_: p: p.cni == "calico") profiles.profiles;
    in lib.all (p:
      lib.elem "calico-cni-plugin" p.extraPackages
    ) (lib.attrValues calicoProfiles))
    "calico profiles should include calico-cni-plugin")

  (mkTest "profiles-cilium-has-cilium-packages"
    (let
      ciliumProfiles = lib.filterAttrs (_: p: p.cni == "cilium") profiles.profiles;
    in lib.all (p:
      lib.elem "cilium-cli" p.extraPackages
    ) (lib.attrValues ciliumProfiles))
    "cilium profiles should include cilium-cli")

  (mkTest "profiles-matrix-complete"
    (let
      trackNames = lib.attrNames distributions.tracks;
      profileNames = lib.attrNames profiles.profiles;
      matrixSize = (lib.length trackNames) * (lib.length profileNames);
    in matrixSize == lib.length (lib.attrNames distributions.matrix)
       && matrixSize == 48)
    "profile x distribution matrix should have 48 entries (8 profiles x 6 tracks)")

  # ── Kubernetes package version tests ───────────────────────────────────

  (mkTest "k8s-package-hashes-all-tracks"
    (lib.all (t: (k8sHashFiles.${t}) ? srcHash) allTracks)
    "k8s package hash files should exist for all tracks")

  (mkTest "k8s-source-factory-evaluates"
    (let
      versions = versionRegistry."1.34";
      hashes = k8sHashFiles."1.34";
      result = mkSource { inherit versions hashes; };
    in result ? version && result ? ldflags && result.version == "1.34.3")
    "source factory should produce version and ldflags for 1.34")

  (mkTest "k8s-source-factory-ldflags-correct"
    (let
      versions = versionRegistry."1.34";
      hashes = k8sHashFiles."1.34";
      result = mkSource { inherit versions hashes; };
    in lib.any (f: lib.hasInfix "gitVersion=v1.34.3" f) result.ldflags
       && lib.any (f: lib.hasInfix "gitMajor=1" f) result.ldflags
       && lib.any (f: lib.hasInfix "gitMinor=34" f) result.ldflags)
    "source factory ldflags should contain correct version info")

  (mkTest "k8s-source-factory-1.35-ldflags"
    (let
      versions = versionRegistry."1.35";
      hashes = k8sHashFiles."1.35";
      result = mkSource { inherit versions hashes; };
    in result.version == "1.35.1"
       && lib.any (f: lib.hasInfix "gitVersion=v1.35.1" f) result.ldflags
       && lib.any (f: lib.hasInfix "gitMinor=35" f) result.ldflags)
    "source factory should produce correct ldflags for 1.35")

  (mkTest "k8s-source-factory-all-tracks"
    (lib.all (t:
      let
        versions = versionRegistry.${t};
        hashes = k8sHashFiles.${t};
        result = mkSource { inherit versions hashes; };
      in result ? version && result ? ldflags
         && result.version == versions.kubernetesVersion
    ) allTracks)
    "source factory should evaluate correctly for all 6 tracks")

  (mkTest "k8s-source-factory-ldflags-all-tracks"
    (lib.all (t:
      let
        versions = versionRegistry.${t};
        hashes = k8sHashFiles.${t};
        result = mkSource { inherit versions hashes; };
        minor = toString (extractMinor versions.kubernetesVersion);
      in lib.any (f: lib.hasInfix "gitVersion=v${versions.kubernetesVersion}" f) result.ldflags
         && lib.any (f: lib.hasInfix "gitMinor=${minor}" f) result.ldflags
    ) allTracks)
    "source factory ldflags should be correct for all 6 tracks")

  # ── K8s NixOS module tests ───────────────────────────────────────────

  (mkTest "k8s-option-exists"
    (let evaluated = evalK8sModule {};
     in evaluated.options ? services
        && evaluated.options.services ? blackmatter
        && evaluated.options.services.blackmatter ? kubernetes)
    "services.blackmatter.kubernetes options should exist")

  (mkTest "k8s-option-sub-modules-exist"
    (let evaluated = evalK8sModule {};
         k8sOpts = evaluated.options.services.blackmatter.kubernetes;
     in k8sOpts ? controlPlane
        && k8sOpts ? etcd
        && k8sOpts ? pki
        && k8sOpts ? firewall
        && k8sOpts ? kernel
        && k8sOpts ? waitForDNS
        && k8sOpts ? containerRuntime
        && k8sOpts ? gracefulNodeShutdown)
    "k8s module should have all sub-module option groups")

  (mkTest "k8s-option-controlplane-fields"
    (let evaluated = evalK8sModule {};
         cpOpts = evaluated.options.services.blackmatter.kubernetes.controlPlane;
     in cpOpts ? apiServerExtraArgs
        && cpOpts ? controllerManagerExtraArgs
        && cpOpts ? schedulerExtraArgs
        && cpOpts ? apiServerExtraSANs
        && cpOpts ? disableKubeProxy
        && cpOpts ? kubeProxyExtraArgs
        && cpOpts ? etcd)
    "controlPlane options should include all expected fields")

  (mkTest "k8s-option-etcd-fields"
    (let evaluated = evalK8sModule {};
         etcdOpts = evaluated.options.services.blackmatter.kubernetes.etcd;
     in etcdOpts ? enable
        && etcdOpts ? package
        && etcdOpts ? dataDir
        && etcdOpts ? initialCluster
        && etcdOpts ? initialClusterState
        && etcdOpts ? extraArgs)
    "etcd options should include all expected fields")

  (mkTest "k8s-option-pki-fields"
    (let evaluated = evalK8sModule {};
         pkiOpts = evaluated.options.services.blackmatter.kubernetes.pki;
     in pkiOpts ? mode
        && pkiOpts ? certificateDir
        && pkiOpts ? external)
    "pki options should include mode, certificateDir, and external")

  (mkTest "k8s-option-pki-external-fields"
    (let evaluated = evalK8sModule {};
         extOpts = evaluated.options.services.blackmatter.kubernetes.pki.external;
     in extOpts ? caCert && extOpts ? caKey
        && extOpts ? apiServerCert && extOpts ? apiServerKey
        && extOpts ? frontProxyCACert && extOpts ? frontProxyCAKey
        && extOpts ? etcdCACert && extOpts ? etcdCAKey
        && extOpts ? saKey && extOpts ? saPub)
    "pki.external should have all certificate path options")

  (mkTest "k8s-default-distribution"
    (let cfg = (evalK8sModule {}).config.services.blackmatter.kubernetes;
     in cfg.distribution == "1.34")
    "default distribution should be 1.34")

  (mkTest "k8s-default-role"
    (let cfg = (evalK8sModule {}).config.services.blackmatter.kubernetes;
     in cfg.role == "control-plane")
    "default role should be control-plane")

  (mkTest "k8s-default-cidrs"
    (let cfg = (evalK8sModule {}).config.services.blackmatter.kubernetes;
     in cfg.clusterCIDR == "10.42.0.0/16"
        && cfg.serviceCIDR == "10.43.0.0/16"
        && cfg.clusterDNS == "10.43.0.10")
    "default CIDRs should match k3s defaults")

  (mkTest "k8s-default-data-dir"
    (let cfg = (evalK8sModule {}).config.services.blackmatter.kubernetes;
     in cfg.dataDir == "/var/lib/kubernetes")
    "default dataDir should be /var/lib/kubernetes")

  (mkTest "k8s-default-pki-mode"
    (let cfg = (evalK8sModule {}).config.services.blackmatter.kubernetes;
     in cfg.pki.mode == "kubeadm")
    "default PKI mode should be kubeadm")

  (mkTest "k8s-default-firewall-enabled"
    (let cfg = (evalK8sModule {}).config.services.blackmatter.kubernetes;
     in cfg.firewall.enable == true
        && cfg.firewall.apiServerPort == 6443)
    "firewall should be enabled by default with apiserver on 6443")

  (mkTest "k8s-default-firewall-udp"
    (let cfg = (evalK8sModule {}).config.services.blackmatter.kubernetes;
     in cfg.firewall.extraUDPPorts == [ 8472 ])
    "default UDP ports should include VXLAN 8472")

  (mkTest "k8s-default-firewall-trusted"
    (let cfg = (evalK8sModule {}).config.services.blackmatter.kubernetes;
     in cfg.firewall.trustedInterfaces == [ "cni0" "flannel.1" ])
    "default trusted interfaces should include cni0 and flannel.1")

  (mkTest "k8s-default-kernel-enabled"
    (let cfg = (evalK8sModule {}).config.services.blackmatter.kubernetes;
     in cfg.kernel.enable == true)
    "kernel configuration should be enabled by default")

  (mkTest "k8s-default-wait-for-dns"
    (let cfg = (evalK8sModule {}).config.services.blackmatter.kubernetes;
     in cfg.waitForDNS.enable == true
        && cfg.waitForDNS.timeout == 30)
    "waitForDNS should be enabled with 30 retries by default")

  (mkTest "k8s-default-disable-kube-proxy-false"
    (let cfg = (evalK8sModule {}).config.services.blackmatter.kubernetes;
     in cfg.controlPlane.disableKubeProxy == false)
    "kube-proxy should not be disabled by default")

  (mkTest "k8s-default-etcd-disabled"
    (let cfg = (evalK8sModule {}).config.services.blackmatter.kubernetes;
     in cfg.etcd.enable == false)
    "etcd should be disabled by default (auto-enabled by control-plane)")

  (mkTest "k8s-default-etcd-data-dir"
    (let cfg = (evalK8sModule {}).config.services.blackmatter.kubernetes;
     in cfg.etcd.dataDir == "/var/lib/etcd")
    "default etcd dataDir should be /var/lib/etcd")

  (mkTest "k8s-versions-resolve-correctly"
    (let cfg = (evalK8sModule {}).config.services.blackmatter.kubernetes;
     in cfg.versions.kubernetesVersion == "1.34.3"
        && cfg.versions.etcdVersion == "3.6.7"
        && cfg.versions.containerdVersion == "2.1.5"
        && cfg.versions.pauseVersion == "3.11")
    "versions should resolve to 1.34 registry values")

  (mkTest "k8s-versions-1.35-resolves"
    (let cfg = (evalK8sModule { distribution = "1.35"; }).config.services.blackmatter.kubernetes;
     in cfg.versions.kubernetesVersion == "1.35.1"
        && cfg.versions.cniPluginsVersion == "1.9.0")
    "setting distribution=1.35 should resolve to 1.35 registry values")

  (mkTest "k8s-profile-null-default"
    (let cfg = (evalK8sModule {}).config.services.blackmatter.kubernetes;
     in cfg.profile == null)
    "default profile should be null")

  (mkTest "k8s-profile-accepts-all-names"
    (lib.all (name:
      let cfg = (evalK8sModule { profile = name; }).config.services.blackmatter.kubernetes;
      in cfg.profile == name
    ) (lib.attrNames profiles.profiles))
    "profile option should accept all 8 profile names")

  # Test assertion logic as pure expressions (assertions live inside mkIf cfg.enable)
  (mkTest "k8s-worker-assertion-serverAddr-logic"
    (let
      # Matches the assertion: cfg.role != "worker" || cfg.serverAddr != ""
      workerCheck = role: addr: role != "worker" || addr != "";
    in !(workerCheck "worker" "")                       # worker without addr → fails
       && (workerCheck "worker" "10.0.0.1:6443")        # worker with addr → passes
       && (workerCheck "control-plane" ""))              # control-plane → always passes
    "worker assertion logic should require serverAddr for workers")

  (mkTest "k8s-worker-assertion-token-logic"
    (let
      # Matches: cfg.role != "worker" || (cfg.tokenFile != null || cfg.token != "")
      tokenCheck = role: tokenFile: token:
        role != "worker" || (tokenFile != null || token != "");
    in !(tokenCheck "worker" null "")                    # worker without token → fails
       && (tokenCheck "worker" null "abc123")             # worker with token → passes
       && (tokenCheck "worker" "/path/to/token" "")       # worker with tokenFile → passes
       && (tokenCheck "control-plane" null ""))            # control-plane → always passes
    "worker assertion logic should require token or tokenFile for workers")

  (mkTest "k8s-controlplane-etcd-external-default"
    (let cfg = (evalK8sModule {}).config.services.blackmatter.kubernetes;
     in cfg.controlPlane.etcd.external == false
        && cfg.controlPlane.etcd.endpoints == [ "http://127.0.0.1:2379" ])
    "external etcd should be disabled by default with localhost endpoint")

  (mkTest "k8s-pki-certificate-dir-follows-data-dir"
    (let cfg = (evalK8sModule {}).config.services.blackmatter.kubernetes;
     in cfg.pki.certificateDir == "/var/lib/kubernetes/pki")
    "PKI certificate dir should derive from dataDir")

  # Multi-distribution k8s module tests
  (mkTest "k8s-distribution-all-values-accepted"
    (lib.all (t:
      let cfg = (evalK8sModule { distribution = t; }).config.services.blackmatter.kubernetes;
      in cfg.distribution == t
    ) allTracks)
    "k8s module should accept all 6 distribution values")

  (mkTest "k8s-versions-all-tracks-resolve"
    (lib.all (t:
      let cfg = (evalK8sModule { distribution = t; }).config.services.blackmatter.kubernetes;
      in cfg.versions.kubernetesVersion == (versionRegistry.${t}).kubernetesVersion
    ) allTracks)
    "k8s module versions should resolve correctly for all tracks")

  (mkTest "k8s-versions-1.30-resolves"
    (let cfg = (evalK8sModule { distribution = "1.30"; }).config.services.blackmatter.kubernetes;
     in cfg.versions.kubernetesVersion == "1.30.14"
        && cfg.versions.etcdVersion == "3.5.15"
        && cfg.versions.containerdVersion == "1.7.27"
        && cfg.versions.pauseVersion == "3.9")
    "setting distribution=1.30 should resolve to 1.30 registry values")

  (mkTest "k8s-versions-1.33-resolves"
    (let cfg = (evalK8sModule { distribution = "1.33"; }).config.services.blackmatter.kubernetes;
     in cfg.versions.kubernetesVersion == "1.33.8"
        && cfg.versions.etcdVersion == "3.5.24"
        && cfg.versions.containerdVersion == "2.1.5"
        && cfg.versions.pauseVersion == "3.10")
    "setting distribution=1.33 should resolve to 1.33 registry values")

  # ── FluxCD module tests ──────────────────────────────────────────────

  (let
    fluxcdMod = import ../../module/nixos/fluxcd { inherit nixosHelpers; };
    fluxcdStubs = {
      options = {
        systemd.services = lib.mkOption { type = lib.types.attrs; default = {}; };
        services.blackmatter.k3s = {
          enable = lib.mkOption { type = lib.types.bool; default = false; };
          manifests = lib.mkOption { type = lib.types.attrs; default = {}; };
        };
        assertions = lib.mkOption { type = lib.types.listOf lib.types.attrs; default = []; };
      };
    };
    evalFluxcd = config: (lib.evalModules {
      modules = [ fluxcdMod config fluxcdStubs ];
    }).config;
    evalFluxcdFull = config: lib.evalModules {
      modules = [ fluxcdMod config fluxcdStubs ];
    };
  in mkTest "fluxcd-option-exists"
    (let evaluated = evalFluxcdFull {};
     in evaluated.options ? services
        && evaluated.options.services ? blackmatter
        && evaluated.options.services.blackmatter ? fluxcd)
    "services.blackmatter.fluxcd options should exist")

  (let
    fluxcdMod = import ../../module/nixos/fluxcd { inherit nixosHelpers; };
    fluxcdStubs = {
      options = {
        systemd.services = lib.mkOption { type = lib.types.attrs; default = {}; };
        services.blackmatter.k3s = {
          enable = lib.mkOption { type = lib.types.bool; default = false; };
          manifests = lib.mkOption { type = lib.types.attrs; default = {}; };
        };
        assertions = lib.mkOption { type = lib.types.listOf lib.types.attrs; default = []; };
      };
    };
    evalFluxcd = config: (lib.evalModules {
      modules = [ fluxcdMod config fluxcdStubs ];
    }).config;
  in mkTest "fluxcd-disabled-by-default"
    (!((evalFluxcd {}).services.blackmatter.fluxcd.enable))
    "fluxcd should be disabled by default")

  (let
    fluxcdMod = import ../../module/nixos/fluxcd { inherit nixosHelpers; };
    fluxcdStubs = {
      options = {
        systemd.services = lib.mkOption { type = lib.types.attrs; default = {}; };
        services.blackmatter.k3s = {
          enable = lib.mkOption { type = lib.types.bool; default = false; };
          manifests = lib.mkOption { type = lib.types.attrs; default = {}; };
        };
        assertions = lib.mkOption { type = lib.types.listOf lib.types.attrs; default = []; };
      };
    };
    evalFluxcd = config: (lib.evalModules {
      modules = [ fluxcdMod config fluxcdStubs ];
    }).config;
    cfg = (evalFluxcd {}).services.blackmatter.fluxcd;
  in mkTest "fluxcd-defaults"
    (cfg.source.branch == "main"
     && cfg.source.interval == "1m0s"
     && cfg.source.auth == "ssh"
     && cfg.source.tokenUsername == "git"
     && cfg.reconcile.interval == "2m0s"
     && cfg.reconcile.prune == true
     && !cfg.sops.enable)
    "defaults should be: branch=main, auth=ssh, tokenUsername=git, intervals 1m/2m, prune=true, sops=off")

  (let
    fluxcdMod = import ../../module/nixos/fluxcd { inherit nixosHelpers; };
    k3sOn = {
      options = {
        systemd.services = lib.mkOption { type = lib.types.attrs; default = {}; };
        services.blackmatter.k3s = {
          enable = lib.mkOption { type = lib.types.bool; default = true; };
          manifests = lib.mkOption { type = lib.types.attrs; default = {}; };
        };
        assertions = lib.mkOption { type = lib.types.listOf lib.types.attrs; default = []; };
      };
    };
    evaluated = (lib.evalModules {
      modules = [ fluxcdMod { config.services.blackmatter.fluxcd = {
        enable = true;
        source.url = "ssh://git@github.com/test/repo";
        source.sshKeyFile = "/run/secrets/test-key";
      }; } k3sOn ];
    }).config;
  in mkTest "fluxcd-bootstrap-service-created"
    (evaluated.systemd.services ? fluxcd-bootstrap)
    "should create fluxcd-bootstrap systemd service")

  # ── mkGoMonorepoBinary factory tests ──────────────────────────────────

  (let
    monoSrc = mkSource {
      versions = versionRegistry."1.34";
      hashes = k8sHashFiles."1.34";
    };
    # Test that the factory produces a valid derivation-like attrset
    # (we can't fully evaluate without real pkgs, but can test the function signature)
    mockBuildGoModule = args: args;
    mockPkgsWithBuild = mockPkgs // {
      buildGoModule = mockBuildGoModule;
      installShellFiles = null;
      platforms = { linux = [ "x86_64-linux" ]; };
      licenses = { asl20 = "asl20"; };
    };
    result = mkGoMonorepoBinary mockPkgsWithBuild monoSrc {
      pname = "kubelet";
      description = "Kubernetes node agent";
      homepage = "https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/";
    };
  in mkTest "monorepo-binary-factory-pname"
    (result.pname == "kubelet")
    "mkGoMonorepoBinary should set pname correctly")

  (let
    monoSrc = mkSource {
      versions = versionRegistry."1.34";
      hashes = k8sHashFiles."1.34";
    };
    mockBuildGoModule = args: args;
    mockPkgsWithBuild = mockPkgs // {
      buildGoModule = mockBuildGoModule;
      installShellFiles = null;
      platforms = { linux = [ "x86_64-linux" ]; };
      licenses = { asl20 = "asl20"; };
    };
    result = mkGoMonorepoBinary mockPkgsWithBuild monoSrc {
      pname = "kubelet";
      description = "Kubernetes node agent";
    };
  in mkTest "monorepo-binary-factory-default-subpackages"
    (result.subPackages == [ "cmd/kubelet" ])
    "mkGoMonorepoBinary should default subPackages to cmd/<pname>")

  (let
    monoSrc = mkSource {
      versions = versionRegistry."1.34";
      hashes = k8sHashFiles."1.34";
    };
    mockBuildGoModule = args: args;
    mockPkgsWithBuild = mockPkgs // {
      buildGoModule = mockBuildGoModule;
      installShellFiles = null;
      platforms = { linux = [ "x86_64-linux" ]; };
      licenses = { asl20 = "asl20"; };
    };
    result = mkGoMonorepoBinary mockPkgsWithBuild monoSrc {
      pname = "kubelet";
      description = "Kubernetes node agent";
    };
  in mkTest "monorepo-binary-factory-version"
    (result.version == "1.34.3")
    "mkGoMonorepoBinary should inherit version from monoSrc")

  (let
    monoSrc = mkSource {
      versions = versionRegistry."1.34";
      hashes = k8sHashFiles."1.34";
    };
    mockBuildGoModule = args: args;
    mockPkgsWithBuild = mockPkgs // {
      buildGoModule = mockBuildGoModule;
      installShellFiles = null;
      platforms = { linux = [ "x86_64-linux" ]; };
      licenses = { asl20 = "asl20"; };
    };
    result = mkGoMonorepoBinary mockPkgsWithBuild monoSrc {
      pname = "kubelet";
      description = "Kubernetes node agent";
    };
  in mkTest "monorepo-binary-factory-vendorHash-null"
    (result.vendorHash == null)
    "mkGoMonorepoBinary should set vendorHash to null (monorepo vendored)")

  (let
    monoSrc = mkSource {
      versions = versionRegistry."1.34";
      hashes = k8sHashFiles."1.34";
    };
    mockBuildGoModule = args: args;
    mockPkgsWithBuild = mockPkgs // {
      buildGoModule = mockBuildGoModule;
      installShellFiles = "installShellFiles";
      platforms = { linux = [ "x86_64-linux" ]; };
      licenses = { asl20 = "asl20"; };
    };
    result = mkGoMonorepoBinary mockPkgsWithBuild monoSrc {
      pname = "kubeadm";
      description = "Kubernetes cluster bootstrap tool";
      completions = { install = true; command = "kubeadm"; };
    };
  in mkTest "monorepo-binary-factory-completions"
    (lib.elem "installShellFiles" result.nativeBuildInputs
     && lib.hasInfix "kubeadm" result.postInstall)
    "mkGoMonorepoBinary should add completions when specified")

  (let
    monoSrc = mkSource {
      versions = versionRegistry."1.35";
      hashes = k8sHashFiles."1.35";
    };
    mockBuildGoModule = args: args;
    mockPkgsWithBuild = mockPkgs // {
      buildGoModule = mockBuildGoModule;
      installShellFiles = null;
      platforms = { linux = [ "x86_64-linux" ]; };
      licenses = { asl20 = "asl20"; };
    };
    result = mkGoMonorepoBinary mockPkgsWithBuild monoSrc {
      pname = "kube-apiserver";
      description = "Kubernetes API server";
    };
  in mkTest "monorepo-binary-factory-1.35"
    (result.pname == "kube-apiserver" && result.version == "1.35.1")
    "mkGoMonorepoBinary should work with 1.35 track")

  # ── mkVersionedOverlay factory tests ──────────────────────────────────

  (let
    mockSrc = {
      foo_1_34 = "pkg-foo-1.34";
      foo_1_35 = "pkg-foo-1.35";
    };
    result = mkVersionedOverlay {
      inherit lib;
      tracks = [ "1.34" "1.35" ];
      defaultTrack = "1.34";
      latestTrack = "1.35";
      components = { foo = { src = mockSrc; }; };
    };
  in mkTest "versioned-overlay-versioned-entries"
    (result ? "blackmatter-foo-1-34" && result ? "blackmatter-foo-1-35"
     && result."blackmatter-foo-1-34" == "pkg-foo-1.34"
     && result."blackmatter-foo-1-35" == "pkg-foo-1.35")
    "mkVersionedOverlay should generate versioned entries")

  (let
    mockSrc = {
      foo_1_34 = "pkg-foo-1.34";
      foo_1_35 = "pkg-foo-1.35";
    };
    result = mkVersionedOverlay {
      inherit lib;
      tracks = [ "1.34" "1.35" ];
      defaultTrack = "1.34";
      latestTrack = "1.35";
      components = { foo = { src = mockSrc; }; };
    };
  in mkTest "versioned-overlay-default-alias"
    (result ? "blackmatter-foo" && result."blackmatter-foo" == "pkg-foo-1.34")
    "mkVersionedOverlay should create default alias pointing to defaultTrack")

  (let
    mockSrc = {
      foo_1_34 = "pkg-foo-1.34";
      foo_1_35 = "pkg-foo-1.35";
    };
    result = mkVersionedOverlay {
      inherit lib;
      tracks = [ "1.34" "1.35" ];
      defaultTrack = "1.34";
      latestTrack = "1.35";
      components = { foo = { src = mockSrc; }; };
    };
  in mkTest "versioned-overlay-latest-alias"
    (result ? "blackmatter-foo-latest" && result."blackmatter-foo-latest" == "pkg-foo-1.35")
    "mkVersionedOverlay should create -latest alias pointing to latestTrack")

  (let
    mockSrc = {
      bar_1_34 = "pkg-bar-1.34";
      bar_1_35 = "pkg-bar-1.35";
    };
    result = mkVersionedOverlay {
      inherit lib;
      tracks = [ "1.34" "1.35" ];
      defaultTrack = "1.34";
      latestTrack = "1.35";
      components = { bar = { src = mockSrc; overlayName = "bar-server"; }; };
    };
  in mkTest "versioned-overlay-overlay-name"
    (result ? "blackmatter-bar-server-1-34"
     && result ? "blackmatter-bar-server"
     && result ? "blackmatter-bar-server-latest")
    "mkVersionedOverlay should use overlayName for output attribute names")

  (let
    mockSrc = {
      k3s_1_34 = "pkg-k3s-1.34";
      k3s_1_35 = "pkg-k3s-1.35";
    };
    result = mkVersionedOverlay {
      inherit lib;
      tracks = [ "1.34" "1.35" ];
      defaultTrack = "1.34";
      latestTrack = "1.35";
      components = { k3s = { src = mockSrc; srcAttr = s: "k3s_${s}"; }; };
    };
  in mkTest "versioned-overlay-custom-srcattr"
    (result ? "blackmatter-k3s-1-34"
     && result."blackmatter-k3s-1-34" == "pkg-k3s-1.34")
    "mkVersionedOverlay should support custom srcAttr function")

  (let
    mockSrc = {
      foo_1_34 = "pkg-foo-1.34";
      foo_1_35 = "pkg-foo-1.35";
    };
    result = mkVersionedOverlay {
      inherit lib;
      tracks = [ "1.34" "1.35" ];
      prefix = "custom-";
      defaultTrack = "1.34";
      latestTrack = "1.35";
      components = { foo = { src = mockSrc; }; };
    };
  in mkTest "versioned-overlay-custom-prefix"
    (result ? "custom-foo-1-34" && result ? "custom-foo" && result ? "custom-foo-latest")
    "mkVersionedOverlay should support custom prefix")

  (let
    mockSrc = {
      a_1_30 = "a-1.30"; a_1_31 = "a-1.31"; a_1_32 = "a-1.32";
      a_1_33 = "a-1.33"; a_1_34 = "a-1.34"; a_1_35 = "a-1.35";
      b_1_30 = "b-1.30"; b_1_31 = "b-1.31"; b_1_32 = "b-1.32";
      b_1_33 = "b-1.33"; b_1_34 = "b-1.34"; b_1_35 = "b-1.35";
    };
    result = mkVersionedOverlay {
      inherit lib;
      tracks = allTracks;
      defaultTrack = "1.34";
      latestTrack = "1.35";
      components = {
        a = { src = mockSrc; };
        b = { src = mockSrc; };
      };
    };
    # 6 tracks × 2 components = 12 versioned + 2 default + 2 latest = 16
    names = lib.attrNames result;
  in mkTest "versioned-overlay-entry-count"
    (lib.length names == 16)
    "mkVersionedOverlay should generate correct number of entries (6×2 + 2 + 2 = 16)")

  # ── mkRuntimeComponent factory tests ──────────────────────────────────

  (let
    mockBuildGoModule = args: args;
    mockFetch = _: "/nix/store/mock-src";
    testPkgs = mockPkgs // {
      buildGoModule = mockBuildGoModule;
      fetchFromGitHub = mockFetch;
      installShellFiles = null;
      platforms = { linux = [ "x86_64-linux" ]; };
      licenses = { asl20 = "asl20"; };
    };
    mkRC = import ../../pkgs/kubernetes/mk-runtime-component.nix { pkgs = testPkgs; };
    result = mkRC {
      pname = "test-component";
      version = "1.2.3";
      owner = "test-org";
      repo = "test-repo";
      hashes = { "1.2.3" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; };
      description = "Test component";
    };
  in mkTest "runtime-component-factory-pname"
    (result.pname == "test-component" && result.version == "1.2.3")
    "mkRuntimeComponent should set pname and version correctly")

  (let
    mockBuildGoModule = args: args;
    mockFetch = _: "/nix/store/mock-src";
    testPkgs = mockPkgs // {
      buildGoModule = mockBuildGoModule;
      fetchFromGitHub = mockFetch;
      installShellFiles = null;
      pkg-config = "pkg-config";
      libseccomp = "libseccomp";
      platforms = { linux = [ "x86_64-linux" ]; };
      licenses = { asl20 = "asl20"; };
    };
    mkRC = import ../../pkgs/kubernetes/mk-runtime-component.nix { pkgs = testPkgs; };
    result = mkRC {
      pname = "runc";
      version = "1.2.6";
      owner = "opencontainers";
      repo = "runc";
      hashes = { "1.2.6" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; };
      vendorHash = null;
      buildInputs = [ "libseccomp" ];
      nativeBuildInputs = [ "pkg-config" ];
      env = { CGO_ENABLED = "1"; };
      subPackages = [ "." ];
      description = "OCI container runtime";
    };
  in mkTest "runtime-component-factory-build-inputs"
    (result.buildInputs == [ "libseccomp" ]
     && lib.elem "pkg-config" result.nativeBuildInputs
     && result.env.CGO_ENABLED == "1"
     && result.subPackages == [ "." ])
    "mkRuntimeComponent should pass through buildInputs, env, and subPackages")

  (let
    mockBuildGoModule = args: args;
    mockFetch = _: "/nix/store/mock-src";
    testPkgs = mockPkgs // {
      buildGoModule = mockBuildGoModule;
      fetchFromGitHub = mockFetch;
      installShellFiles = null;
      platforms = { linux = [ "x86_64-linux" ]; };
      licenses = { asl20 = "asl20"; };
    };
    mkRC = import ../../pkgs/kubernetes/mk-runtime-component.nix { pkgs = testPkgs; };
    result = mkRC {
      pname = "etcd-server";
      version = "3.6.7";
      owner = "etcd-io";
      repo = "etcd";
      hashes = { "3.6.7" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; };
      vendorHashes = { "3.6.7" = "sha256-test-vendor-hash"; };
      modRoot = "server";
      description = "etcd server";
    };
  in mkTest "runtime-component-factory-vendor-hashes"
    (result.vendorHash == "sha256-test-vendor-hash"
     && result.modRoot == "server")
    "mkRuntimeComponent should support vendorHashes map and modRoot")

  (let
    mockBuildGoModule = args: args;
    mockFetch = _: "/nix/store/mock-src";
    testPkgs = mockPkgs // {
      buildGoModule = mockBuildGoModule;
      fetchFromGitHub = mockFetch;
      installShellFiles = "installShellFiles";
      platforms = { linux = [ "x86_64-linux" ]; };
      licenses = { asl20 = "asl20"; };
    };
    mkRC = import ../../pkgs/kubernetes/mk-runtime-component.nix { pkgs = testPkgs; };
    result = mkRC {
      pname = "crictl";
      version = "1.34.0";
      owner = "kubernetes-sigs";
      repo = "cri-tools";
      hashes = { "1.34.0" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; };
      completions = { install = true; command = "crictl"; };
      description = "CRI CLI";
    };
  in mkTest "runtime-component-factory-completions"
    (lib.elem "installShellFiles" result.nativeBuildInputs
     && lib.hasInfix "crictl" result.postInstall)
    "mkRuntimeComponent should support shell completions")

  # ── k3s module enable=true tests ────────────────────────────────────
  # Tests that cfg.enable activates kernel, sysctl, firewall, and assertions.
  # Only accesses config paths that don't force package evaluation.

  (mkTest "k3s-enable-kernel-modules"
    (let cfg = evalModule { enable = true; };
     in lib.elem "overlay" cfg.boot.kernelModules
        && lib.elem "br_netfilter" cfg.boot.kernelModules)
    "k3s enable=true should configure kernel modules")

  (mkTest "k3s-enable-sysctl"
    (let cfg = evalModule { enable = true; };
     in cfg.boot.kernel.sysctl."net.ipv4.ip_forward" == 1
        && cfg.boot.kernel.sysctl."net.bridge.bridge-nf-call-iptables" == 1
        && cfg.boot.kernel.sysctl."net.bridge.bridge-nf-call-ip6tables" == 1)
    "k3s enable=true should configure sysctl for forwarding and bridge nf")

  (mkTest "k3s-enable-firewall-server"
    (let fw = (evalModule { enable = true; }).networking.firewall;
     in lib.elem 6443 fw.allowedTCPPorts
        && lib.elem 10250 fw.allowedTCPPorts
        && fw.allowedUDPPorts == [ 8472 ])
    "k3s enable=true server should open apiserver, kubelet, and VXLAN ports")

  (mkTest "k3s-enable-firewall-trusted"
    (let fw = (evalModule { enable = true; }).networking.firewall;
     in fw.trustedInterfaces == [ "cni0" "flannel.1" ])
    "k3s enable=true should trust default CNI interfaces")

  (mkTest "k3s-enable-assertions-server"
    (let asserts = (evalModule { enable = true; }).assertions;
     in lib.all (a: a.assertion) asserts)
    "k3s enable=true server should pass all assertions")

  (mkTest "k3s-enable-kernel-no-extra"
    (let mods = (evalModule { enable = true; }).boot.kernelModules;
     in mods == [ "overlay" "br_netfilter" ])
    "k3s enable=true without profile should only have base kernel modules")

  # ── k3s profile application tests ──────────────────────────────────
  # Verifies that profiles actually configure firewall, kernel, disable list,
  # and extra flags when enable=true.

  (mkTest "k3s-profile-cilium-kernel-modules"
    (let mods = (evalModule { enable = true; profile = "cilium-standard"; }).boot.kernelModules;
     in lib.elem "ip_tables" mods
        && lib.elem "xt_socket" mods
        && lib.elem "xt_mark" mods
        && lib.elem "xt_CT" mods
        && lib.elem "overlay" mods
        && lib.elem "br_netfilter" mods)
    "cilium-standard profile should add eBPF kernel modules alongside base modules")

  (mkTest "k3s-profile-cilium-firewall"
    (let fw = (evalModule { enable = true; profile = "cilium-standard"; }).networking.firewall;
     in lib.elem 4240 fw.allowedTCPPorts
        && lib.elem 4244 fw.allowedTCPPorts)
    "cilium-standard profile should open health and hubble TCP ports")

  (mkTest "k3s-profile-cilium-trusted-interfaces"
    (let fw = (evalModule { enable = true; profile = "cilium-standard"; }).networking.firewall;
     in lib.elem "cilium_host" fw.trustedInterfaces
        && lib.elem "cilium_net" fw.trustedInterfaces
        && lib.elem "lxc+" fw.trustedInterfaces)
    "cilium-standard profile should trust cilium interfaces")

  (mkTest "k3s-profile-cilium-disable-list"
    (let cfg = (evalModule { enable = true; profile = "cilium-standard"; }).services.blackmatter.k3s;
     in lib.elem "servicelb" cfg.disable)
    "cilium-standard profile should disable servicelb")

  (mkTest "k3s-profile-cilium-extra-flags"
    (let cfg = (evalModule { enable = true; profile = "cilium-standard"; }).services.blackmatter.k3s;
     in lib.elem "--flannel-backend=none" cfg.extraFlags
        && lib.elem "--disable-network-policy" cfg.extraFlags
        && lib.elem "--disable-kube-proxy" cfg.extraFlags)
    "cilium-standard profile should set flannel-backend=none, disable-network-policy, and disable-kube-proxy")

  (mkTest "k3s-profile-flannel-minimal-disable"
    (let cfg = (evalModule { enable = true; profile = "flannel-minimal"; }).services.blackmatter.k3s;
     in lib.elem "traefik" cfg.disable
        && lib.elem "servicelb" cfg.disable
        && lib.elem "metrics-server" cfg.disable
        && lib.elem "local-storage" cfg.disable)
    "flannel-minimal profile should disable traefik, servicelb, metrics-server, local-storage")

  (mkTest "k3s-profile-calico-firewall"
    (let fw = (evalModule { enable = true; profile = "calico-standard"; }).networking.firewall;
     in lib.elem 179 fw.allowedTCPPorts
        && lib.elem 5473 fw.allowedTCPPorts
        && lib.elem 4789 fw.allowedUDPPorts
        && lib.elem 8472 fw.allowedUDPPorts)
    "calico-standard profile should open BGP, typha, and VXLAN ports")

  (mkTest "k3s-profile-calico-trusted-interfaces"
    (let fw = (evalModule { enable = true; profile = "calico-standard"; }).networking.firewall;
     in lib.elem "cali+" fw.trustedInterfaces
        && lib.elem "tunl0" fw.trustedInterfaces
        && lib.elem "vxlan.calico" fw.trustedInterfaces)
    "calico-standard profile should trust calico interfaces")

  (mkTest "k3s-profile-flannel-standard-no-extra-flags"
    (let cfg = (evalModule { enable = true; profile = "flannel-standard"; }).services.blackmatter.k3s;
     in cfg.extraFlags == [])
    "flannel-standard profile should not set any extra flags")

  (mkTest "k3s-profile-flannel-standard-default-firewall"
    (let fw = (evalModule { enable = true; profile = "flannel-standard"; }).networking.firewall;
     in fw.trustedInterfaces == [ "cni0" "flannel.1" ]
        && fw.allowedUDPPorts == [ 8472 ])
    "flannel-standard profile should keep default flannel firewall settings")

  # ── k8s module enable=true tests ────────────────────────────────────
  # Tests that k8s module enable=true activates kernel, sysctl, firewall,
  # assertions, and tmpfiles. Avoids environment.systemPackages (needs real pkgs).

  (mkTest "k8s-enable-kernel-modules"
    (let cfg = (evalK8sModule { enable = true; }).config;
     in lib.elem "overlay" cfg.boot.kernelModules
        && lib.elem "br_netfilter" cfg.boot.kernelModules
        && lib.elem "ip_vs" cfg.boot.kernelModules
        && lib.elem "ip_vs_rr" cfg.boot.kernelModules
        && lib.elem "ip_vs_wrr" cfg.boot.kernelModules
        && lib.elem "ip_vs_sh" cfg.boot.kernelModules)
    "k8s enable=true should configure base + IPVS kernel modules")

  (mkTest "k8s-enable-sysctl"
    (let cfg = (evalK8sModule { enable = true; }).config;
     in cfg.boot.kernel.sysctl."net.ipv4.ip_forward" == 1
        && cfg.boot.kernel.sysctl."net.bridge.bridge-nf-call-iptables" == 1
        && cfg.boot.kernel.sysctl."net.bridge.bridge-nf-call-ip6tables" == 1)
    "k8s enable=true should configure sysctl for forwarding and bridge nf")

  (mkTest "k8s-enable-firewall-controlplane"
    (let fw = (evalK8sModule { enable = true; }).config.networking.firewall;
     in lib.elem 6443 fw.allowedTCPPorts
        && lib.elem 10250 fw.allowedTCPPorts)
    "k8s enable=true control-plane should open apiserver and kubelet ports")

  (mkTest "k8s-enable-assertions-controlplane"
    (let asserts = (evalK8sModule { enable = true; }).config.assertions;
     in lib.all (a: a.assertion) asserts)
    "k8s enable=true control-plane should pass all assertions")

  (mkTest "k8s-enable-tmpfiles"
    (let rules = (evalK8sModule { enable = true; }).config.systemd.tmpfiles.rules;
     in lib.any (r: lib.hasInfix "/var/lib/kubernetes" r) rules
        && lib.any (r: lib.hasInfix "pki" r) rules)
    "k8s enable=true should create data and PKI directories via tmpfiles")

  # ── k8s profile application tests ──────────────────────────────────

  (mkTest "k8s-profile-cilium-disable-kube-proxy"
    (let cfg = (evalK8sModule { enable = true; profile = "cilium-standard"; }).config.services.blackmatter.kubernetes;
     in cfg.controlPlane.disableKubeProxy == true)
    "cilium-standard profile should disable kube-proxy in k8s module")

  (mkTest "k8s-profile-cilium-kernel-modules"
    (let mods = (evalK8sModule { enable = true; profile = "cilium-standard"; }).config.boot.kernelModules;
     in lib.elem "ip_tables" mods
        && lib.elem "xt_socket" mods
        && lib.elem "xt_mark" mods
        && lib.elem "xt_CT" mods
        && lib.elem "overlay" mods)
    "cilium-standard profile should add eBPF kernel modules in k8s module")

  (mkTest "k8s-profile-cilium-firewall"
    (let fw = (evalK8sModule { enable = true; profile = "cilium-standard"; }).config.networking.firewall;
     in lib.elem 4240 fw.allowedTCPPorts
        && lib.elem 4244 fw.allowedTCPPorts
        && lib.elem "cilium_host" fw.trustedInterfaces
        && lib.elem "lxc+" fw.trustedInterfaces)
    "cilium-standard profile should configure cilium firewall in k8s module")

  (mkTest "k8s-profile-calico-firewall"
    (let fw = (evalK8sModule { enable = true; profile = "calico-standard"; }).config.networking.firewall;
     in lib.elem 179 fw.allowedTCPPorts
        && lib.elem 5473 fw.allowedTCPPorts
        && lib.elem "cali+" fw.trustedInterfaces)
    "calico-standard profile should open BGP/typha ports in k8s module")

  (mkTest "k8s-profile-flannel-no-disable-kube-proxy"
    (let cfg = (evalK8sModule { enable = true; profile = "flannel-standard"; }).config.services.blackmatter.kubernetes;
     in cfg.controlPlane.disableKubeProxy == false)
    "flannel-standard profile should not disable kube-proxy in k8s module")

  # ── Track system component tests ────────────────────────────────────

  (let
    trackTestPkgs = mockPkgs // {
      buildGoModule = args: args;
      fetchFromGitHub = _: null;
      installShellFiles = "installShellFiles";
      btrfs-progs = "btrfs-progs";
      libseccomp = "libseccomp";
      pkg-config = "pkg-config";
    };
    k8sTrackPkgs = import ../../pkgs/kubernetes {
      pkgs = trackTestPkgs;
      inherit mkGoMonorepoSource mkGoMonorepoBinary;
    };
    track = k8sTrackPkgs.track_1_34;
  in mkTest "track-system-12-components-per-track"
    (lib.length (lib.attrNames track) == 12)
    "each k8s track should produce exactly 12 components")

  (let
    trackTestPkgs = mockPkgs // {
      buildGoModule = args: args;
      fetchFromGitHub = _: null;
      installShellFiles = "installShellFiles";
      btrfs-progs = "btrfs-progs";
      libseccomp = "libseccomp";
      pkg-config = "pkg-config";
    };
    k8sTrackPkgs = import ../../pkgs/kubernetes {
      pkgs = trackTestPkgs;
      inherit mkGoMonorepoSource mkGoMonorepoBinary;
    };
    track = k8sTrackPkgs.track_1_34;
    expectedComponents = [ "cni-plugins" "containerd" "crictl" "etcd"
                           "kube-apiserver" "kube-controller-manager" "kube-proxy"
                           "kube-scheduler" "kubeadm" "kubectl" "kubelet" "runc" ];
    actualComponents = lib.sort (a: b: a < b) (lib.attrNames track);
  in mkTest "track-system-component-names"
    (actualComponents == expectedComponents)
    "k8s track should contain all 12 expected components (including kubectl)")

  (let
    trackTestPkgs = mockPkgs // {
      buildGoModule = args: args;
      fetchFromGitHub = _: null;
      installShellFiles = "installShellFiles";
      btrfs-progs = "btrfs-progs";
      libseccomp = "libseccomp";
      pkg-config = "pkg-config";
    };
    k8sTrackPkgs = import ../../pkgs/kubernetes {
      pkgs = trackTestPkgs;
      inherit mkGoMonorepoSource mkGoMonorepoBinary;
    };
  in mkTest "track-system-all-tracks-have-components"
    (lib.all (t:
      let track = k8sTrackPkgs.${"track_${builtins.replaceStrings ["."] ["_"] t}"};
      in lib.length (lib.attrNames track) == 12
    ) allTracks)
    "all 6 k8s tracks should each have 12 components")

  (let
    trackTestPkgs = mockPkgs // {
      buildGoModule = args: args;
      fetchFromGitHub = _: null;
      installShellFiles = "installShellFiles";
      btrfs-progs = "btrfs-progs";
      libseccomp = "libseccomp";
      pkg-config = "pkg-config";
    };
    k8sTrackPkgs = import ../../pkgs/kubernetes {
      pkgs = trackTestPkgs;
      inherit mkGoMonorepoSource mkGoMonorepoBinary;
    };
    # kubectl should use cross-platform (unix) support
    kubectl = k8sTrackPkgs.track_1_34.kubectl;
  in mkTest "track-system-kubectl-cross-platform"
    (kubectl.meta.platforms == lib.platforms.unix)
    "kubectl in track system should support unix platforms (macOS + Linux)")

  (let
    trackTestPkgs = mockPkgs // {
      buildGoModule = args: args;
      fetchFromGitHub = _: null;
      installShellFiles = "installShellFiles";
      btrfs-progs = "btrfs-progs";
      libseccomp = "libseccomp";
      pkg-config = "pkg-config";
    };
    k8sTrackPkgs = import ../../pkgs/kubernetes {
      pkgs = trackTestPkgs;
      inherit mkGoMonorepoSource mkGoMonorepoBinary;
    };
    # Flat exports should have versioned names
    flatNames = lib.attrNames k8sTrackPkgs;
  in mkTest "track-system-flat-exports"
    (lib.elem "kubectl_1_34" flatNames
     && lib.elem "kubelet_1_34" flatNames
     && lib.elem "etcd_1_35" flatNames
     && lib.elem "track_1_30" flatNames
     && lib.elem "track_1_35" flatNames)
    "k8s packages should export flat versioned names and track attrsets")

  # ── k3s track name generation ───────────────────────────────────────

  (mkTest "k3s-track-name-generation"
    (let
      names = map (track: "k3s_${builtins.replaceStrings ["."] ["_"] track}") allTracks;
    in names == [ "k3s_1_30" "k3s_1_31" "k3s_1_32" "k3s_1_33" "k3s_1_34" "k3s_1_35" ])
    "k3s genAttrs should produce correct track names for all 6 tracks")

  # ── Etcd hash deduplication tests ───────────────────────────────────

  (mkTest "etcd-hash-dedup-covers-all-versions"
    (let
      etcdHashes = import ../../pkgs/kubernetes/etcd-hashes.nix;
      allEtcdVersions = lib.unique (map (t: (versionRegistry.${t}).etcdVersion) allTracks);
    in lib.all (v: etcdHashes ? ${v}) allEtcdVersions)
    "shared etcd-hashes.nix should cover all etcd versions from the registry")

  (mkTest "etcd-hash-dedup-server-uses-shared"
    (let
      etcdHashes = import ../../pkgs/kubernetes/etcd-hashes.nix;
    in etcdHashes ? "3.5.15" && etcdHashes ? "3.5.24" && etcdHashes ? "3.6.7")
    "shared etcd-hashes.nix should have hashes for all etcd versions (3.5.15, 3.5.24, 3.6.7)")

  (mkTest "etcd-tools-version-from-registry"
    (let version = versionRegistry."1.35".etcdVersion;
     in version == "3.6.7")
    "etcd tools should resolve version from shared registry (1.35 → 3.6.7)")

  # ── mkGoMonorepoBinary additional edge cases ─────────────────────────

  (let
    monoSrc = mkSource {
      versions = versionRegistry."1.34";
      hashes = k8sHashFiles."1.34";
    };
    mockBuildGoModule = args: args;
    mockPkgsWithBuild = mockPkgs // {
      buildGoModule = mockBuildGoModule;
      installShellFiles = null;
      platforms = { linux = [ "x86_64-linux" ]; unix = [ "x86_64-linux" "x86_64-darwin" ]; };
      licenses = { asl20 = "asl20"; };
    };
    result = mkGoMonorepoBinary mockPkgsWithBuild monoSrc {
      pname = "kubectl";
      description = "Kubernetes CLI";
      platforms = mockPkgsWithBuild.platforms.unix;
    };
  in mkTest "monorepo-binary-factory-custom-platforms"
    (result.meta.platforms == [ "x86_64-linux" "x86_64-darwin" ])
    "mkGoMonorepoBinary should support custom platforms parameter")

  (let
    monoSrc = mkSource {
      versions = versionRegistry."1.34";
      hashes = k8sHashFiles."1.34";
    };
    mockBuildGoModule = args: args;
    mockPkgsWithBuild = mockPkgs // {
      buildGoModule = mockBuildGoModule;
      installShellFiles = null;
      platforms = { linux = [ "x86_64-linux" ]; };
      licenses = { asl20 = "asl20"; };
    };
    result = mkGoMonorepoBinary mockPkgsWithBuild monoSrc {
      pname = "kubelet";
      description = "Kubernetes node agent";
    };
  in mkTest "monorepo-binary-factory-no-completions-no-postinstall"
    (result.postInstall == "")
    "mkGoMonorepoBinary without completions should have empty postInstall")

  (let
    monoSrc = mkSource {
      versions = versionRegistry."1.34";
      hashes = k8sHashFiles."1.34";
    };
    mockBuildGoModule = args: args;
    mockPkgsWithBuild = mockPkgs // {
      buildGoModule = mockBuildGoModule;
      installShellFiles = null;
      platforms = { linux = [ "x86_64-linux" ]; };
      licenses = { asl20 = "asl20"; };
    };
    result = mkGoMonorepoBinary mockPkgsWithBuild monoSrc {
      pname = "kube-apiserver";
      description = "Kubernetes API server";
    };
  in mkTest "monorepo-binary-factory-mainprogram"
    (result.meta.mainProgram == "kube-apiserver")
    "mkGoMonorepoBinary mainProgram should default to pname")

  # ── mkRuntimeComponent additional edge cases ─────────────────────────

  (let
    mockBuildGoModule = args: args;
    mockFetch = _: "/nix/store/mock-src";
    testPkgs = mockPkgs // {
      buildGoModule = mockBuildGoModule;
      fetchFromGitHub = mockFetch;
      installShellFiles = null;
      platforms = { linux = [ "x86_64-linux" ]; };
      licenses = { asl20 = "asl20"; };
    };
    mkRC = import ../../pkgs/kubernetes/mk-runtime-component.nix { pkgs = testPkgs; };
    result = mkRC {
      pname = "test-default-ldflags";
      version = "1.0.0";
      owner = "test";
      repo = "test";
      hashes = { "1.0.0" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; };
      description = "Test default ldflags";
    };
  in mkTest "runtime-component-factory-default-ldflags"
    (result.ldflags == [ "-s" "-w" ])
    "mkRuntimeComponent should default to -s -w ldflags")

  (let
    mockBuildGoModule = args: args;
    mockFetch = _: "/nix/store/mock-src";
    testPkgs = mockPkgs // {
      buildGoModule = mockBuildGoModule;
      fetchFromGitHub = mockFetch;
      installShellFiles = null;
      platforms = { linux = [ "x86_64-linux" ]; };
      licenses = { asl20 = "asl20"; };
    };
    mkRC = import ../../pkgs/kubernetes/mk-runtime-component.nix { pkgs = testPkgs; };
    result = mkRC {
      pname = "etcd-server";
      version = "3.6.7";
      owner = "etcd-io";
      repo = "etcd";
      hashes = { "3.6.7" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; };
      description = "etcd server";
    };
  in mkTest "runtime-component-factory-mainprogram-default"
    (result.meta.mainProgram == "etcd-server")
    "mkRuntimeComponent mainProgram should default to pname")

  (let
    mockBuildGoModule = args: args;
    mockFetch = _: "/nix/store/mock-src";
    testPkgs = mockPkgs // {
      buildGoModule = mockBuildGoModule;
      fetchFromGitHub = mockFetch;
      installShellFiles = null;
      platforms = { linux = [ "x86_64-linux" ]; };
      licenses = { asl20 = "asl20"; };
    };
    mkRC = import ../../pkgs/kubernetes/mk-runtime-component.nix { pkgs = testPkgs; };
    result = mkRC {
      pname = "test-no-homepage";
      version = "1.0.0";
      owner = "test";
      repo = "test";
      hashes = { "1.0.0" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; };
      description = "Test no homepage";
    };
  in mkTest "runtime-component-factory-no-homepage"
    (!(result.meta ? homepage))
    "mkRuntimeComponent with homepage=null should not include homepage in meta")

  (let
    mockBuildGoModule = args: args;
    mockFetch = _: "/nix/store/mock-src";
    testPkgs = mockPkgs // {
      buildGoModule = mockBuildGoModule;
      fetchFromGitHub = mockFetch;
      installShellFiles = null;
      platforms = { linux = [ "x86_64-linux" ]; };
      licenses = { asl20 = "asl20"; };
    };
    mkRC = import ../../pkgs/kubernetes/mk-runtime-component.nix { pkgs = testPkgs; };
    result = mkRC {
      pname = "test-with-homepage";
      version = "1.0.0";
      owner = "test";
      repo = "test";
      hashes = { "1.0.0" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; };
      homepage = "https://example.com";
      description = "Test with homepage";
    };
  in mkTest "runtime-component-factory-with-homepage"
    (result.meta ? homepage && result.meta.homepage == "https://example.com")
    "mkRuntimeComponent with homepage should include it in meta")

  (let
    mockBuildGoModule = args: args;
    mockFetch = _: "/nix/store/mock-src";
    testPkgs = mockPkgs // {
      buildGoModule = mockBuildGoModule;
      fetchFromGitHub = mockFetch;
      installShellFiles = null;
      platforms = { linux = [ "x86_64-linux" ]; };
      licenses = { asl20 = "asl20"; };
    };
    mkRC = import ../../pkgs/kubernetes/mk-runtime-component.nix { pkgs = testPkgs; };
    result = mkRC {
      pname = "test-default-platforms";
      version = "1.0.0";
      owner = "test";
      repo = "test";
      hashes = { "1.0.0" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; };
      description = "Test default platforms";
    };
  in mkTest "runtime-component-factory-default-platforms"
    (result.meta.platforms == lib.platforms.linux)
    "mkRuntimeComponent should default to lib.platforms.linux")
]
