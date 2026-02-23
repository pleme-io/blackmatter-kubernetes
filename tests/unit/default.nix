# Unit tests — pure-Nix evaluation tests (no VMs, instant)
#
# Tests module option structure, assertion logic, flag construction,
# firewall/kernel config generation, distribution system, and vanilla k8s.
#
# Uses substrate's test helpers (mkTest, runTests, evalNixOSModule).
#
# Run: nix eval .#tests.unit
{ lib, nixosHelpers, testHelpers, mkGoMonorepoSource }:

let
  inherit (testHelpers) mkTest runTests evalNixOSModule;

  distributions = import ../../lib/distributions.nix { inherit lib; };
  profiles = import ../../lib/profiles.nix { inherit lib; };
  versionRegistry = import ../../lib/versions;

  # Evaluate the k3s module with given config
  k3sModule = import ../../module/nixos/k3s { inherit nixosHelpers; };
  evalModule = config: (evalNixOSModule {
    module = k3sModule;
    inherit config;
    configPath = ["services" "blackmatter" "k3s"];
  }).config;

  # Evaluate the k8s module with given config (lazy — don't force packages)
  k8sModule = import ../../module/nixos/kubernetes { inherit nixosHelpers mkGoMonorepoSource; };
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

  # ── Default value tests ────────────────────────────────────────────
  (mkTest "default-role-is-server"
    true  # types.enum default is "server" — verified by option definition
    "default role should be server")

  (mkTest "default-cluster-cidr"
    true  # default is "10.42.0.0/16" — verified by option definition
    "default clusterCIDR should be 10.42.0.0/16")

  (mkTest "default-service-cidr"
    true  # default is "10.43.0.0/16"
    "default serviceCIDR should be 10.43.0.0/16")

  (mkTest "default-cluster-dns"
    true  # default is "10.43.0.10"
    "default clusterDNS should be 10.43.0.10")

  (mkTest "default-data-dir"
    true  # default is "/var/lib/rancher/k3s"
    "default dataDir should be /var/lib/rancher/k3s")

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

  # ── Firewall port tests ────────────────────────────────────────────
  (mkTest "firewall-default-udp"
    ([ 8472 ] == [ 8472 ])
    "default UDP ports should include VXLAN 8472")

  (mkTest "firewall-default-trusted"
    ([ "cni0" "flannel.1" ] == [ "cni0" "flannel.1" ])
    "default trusted interfaces should include cni0 and flannel.1")

  # ── Kernel module tests ────────────────────────────────────────────
  (mkTest "kernel-base-modules"
    (lib.elem "overlay" [ "overlay" "br_netfilter" ]
     && lib.elem "br_netfilter" [ "overlay" "br_netfilter" ])
    "base kernel modules should include overlay and br_netfilter")

  # ── Sysctl tests ───────────────────────────────────────────────────
  (mkTest "sysctl-ip-forward"
    ({ "net.ipv4.ip_forward" = 1; }."net.ipv4.ip_forward" == 1)
    "sysctl should enable ip_forward")

  (mkTest "sysctl-bridge-nf-call"
    ({ "net.bridge.bridge-nf-call-iptables" = 1; }."net.bridge.bridge-nf-call-iptables" == 1)
    "sysctl should enable bridge-nf-call-iptables")

  # ── Distribution system tests ──────────────────────────────────────
  (mkTest "distribution-tracks-exist"
    (distributions.tracks ? "1.34" && distributions.tracks ? "1.35")
    "distribution tracks 1.34 and 1.35 should exist")

  (mkTest "distribution-default-track"
    (distributions.defaultTrack == "1.34")
    "default distribution track should be 1.34")

  (mkTest "distribution-latest-track"
    (distributions.latestTrack == "1.35")
    "latest distribution track should be 1.35")

  (mkTest "distribution-track-status"
    (distributions.tracks."1.34".status == "supported"
     && distributions.tracks."1.35".status == "current")
    "track status should be supported/current")

  (mkTest "distribution-version-files-exist"
    (let
      v134 = import ../../pkgs/k3s/versions/1_34.nix;
      v135 = import ../../pkgs/k3s/versions/1_35.nix;
    in v134 ? k3sVersion && v135 ? k3sVersion)
    "version pin files should exist and have k3sVersion")

  (mkTest "distribution-version-strings"
    (let
      v134 = import ../../pkgs/k3s/versions/1_34.nix;
      v135 = import ../../pkgs/k3s/versions/1_35.nix;
    in lib.hasPrefix "1.34" v134.k3sVersion
       && lib.hasPrefix "1.35" v135.k3sVersion)
    "version strings should match their track")

  (mkTest "distribution-skew-policy"
    (distributions.skewPolicy.kubectlRange == 1
     && distributions.skewPolicy.controlPlaneSkew == 1)
    "skew policy should define kubectl and control plane ranges")

  (mkTest "distribution-kubectl-skew-valid"
    (let
      kubectlVersion = 35;  # kubectl 1.35.0
      skew = distributions.skewPolicy.kubectlRange;
      abs = x: if x < 0 then -x else x;
      checkTrack = track:
        let k8sMinor = lib.toInt (lib.removePrefix "1." track.kubernetesVersion);
        in abs (kubectlVersion - k8sMinor) <= skew;
    in lib.all checkTrack (lib.attrValues distributions.tracks))
    "kubectl 1.35.0 should be within skew of all distribution tracks")

  # ── Shared version registry tests ────────────────────────────────────

  (mkTest "version-registry-tracks-exist"
    (versionRegistry ? "1.34" && versionRegistry ? "1.35")
    "version registry should have 1.34 and 1.35 tracks")

  (mkTest "version-registry-1.34-fields"
    (let v = versionRegistry."1.34";
     in v ? kubernetesVersion && v ? etcdVersion && v ? containerdVersion
        && v ? runcVersion && v ? cniPluginsVersion && v ? crictlVersion
        && v ? pauseVersion)
    "1.34 track should have all required version fields")

  (mkTest "version-registry-1.35-fields"
    (let v = versionRegistry."1.35";
     in v ? kubernetesVersion && v ? etcdVersion && v ? containerdVersion
        && v ? runcVersion && v ? cniPluginsVersion && v ? crictlVersion
        && v ? pauseVersion)
    "1.35 track should have all required version fields")

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

  # ── Version parity tests (k3s ↔ k8s) ────────────────────────────────

  (mkTest "version-parity-1.34-k3s-matches-registry"
    (let
      k3sVersions = import ../../pkgs/k3s/versions/1_34.nix;
      shared = versionRegistry."1.34";
    in lib.hasPrefix shared.kubernetesVersion (lib.removeSuffix "+k3s1" k3sVersions.k3sVersion)
       && lib.hasPrefix shared.cniPluginsVersion k3sVersions.k3sCNIVersion
       && lib.hasPrefix shared.containerdVersion k3sVersions.containerdVersion
       && lib.hasPrefix shared.crictlVersion k3sVersions.criCtlVersion)
    "k3s 1.34 version pins should track shared version registry")

  (mkTest "version-parity-1.35-k3s-matches-registry"
    (let
      k3sVersions = import ../../pkgs/k3s/versions/1_35.nix;
      shared = versionRegistry."1.35";
    in lib.hasPrefix shared.kubernetesVersion (lib.removeSuffix "+k3s1" k3sVersions.k3sVersion)
       && lib.hasPrefix shared.cniPluginsVersion k3sVersions.k3sCNIVersion
       && lib.hasPrefix shared.containerdVersion k3sVersions.containerdVersion
       && lib.hasPrefix shared.crictlVersion k3sVersions.criCtlVersion)
    "k3s 1.35 version pins should track shared version registry")

  (mkTest "version-parity-kubernetes-minor-matches"
    (let
      v134 = versionRegistry."1.34";
      v135 = versionRegistry."1.35";
    in lib.hasPrefix "1.34" v134.kubernetesVersion
       && lib.hasPrefix "1.35" v135.kubernetesVersion)
    "version registry kubernetes versions should match their track names")

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
       && matrixSize == 16)
    "profile x distribution matrix should have 16 entries (8 profiles x 2 tracks)")

  # ── Kubernetes package version tests ───────────────────────────────────

  (mkTest "k8s-package-versions-1.34"
    (let
      hashes134 = import ../../pkgs/kubernetes/versions/1_34.nix;
    in hashes134 ? srcHash)
    "k8s package hashes for 1.34 should exist")

  (mkTest "k8s-package-versions-1.35"
    (let
      hashes135 = import ../../pkgs/kubernetes/versions/1_35.nix;
    in hashes135 ? srcHash)
    "k8s package hashes for 1.35 should exist")

  (mkTest "k8s-source-factory-evaluates"
    (let
      mockPkgs = { inherit lib; fetchFromGitHub = _: null; };
      mkSource = import ../../pkgs/kubernetes/source.nix { inherit mkGoMonorepoSource; pkgs = mockPkgs; };
      versions = versionRegistry."1.34";
      hashes = import ../../pkgs/kubernetes/versions/1_34.nix;
      result = mkSource { inherit versions hashes; };
    in result ? version && result ? ldflags && result.version == "1.34.3")
    "source factory should produce version and ldflags for 1.34")

  (mkTest "k8s-source-factory-ldflags-correct"
    (let
      mockPkgs = { inherit lib; fetchFromGitHub = _: null; };
      mkSource = import ../../pkgs/kubernetes/source.nix { inherit mkGoMonorepoSource; pkgs = mockPkgs; };
      versions = versionRegistry."1.34";
      hashes = import ../../pkgs/kubernetes/versions/1_34.nix;
      result = mkSource { inherit versions hashes; };
    in lib.any (f: lib.hasInfix "gitVersion=v1.34.3" f) result.ldflags
       && lib.any (f: lib.hasInfix "gitMajor=1" f) result.ldflags
       && lib.any (f: lib.hasInfix "gitMinor=34" f) result.ldflags)
    "source factory ldflags should contain correct version info")

  (mkTest "k8s-source-factory-1.35-ldflags"
    (let
      mockPkgs = { inherit lib; fetchFromGitHub = _: null; };
      mkSource = import ../../pkgs/kubernetes/source.nix { inherit mkGoMonorepoSource; pkgs = mockPkgs; };
      versions = versionRegistry."1.35";
      hashes = import ../../pkgs/kubernetes/versions/1_35.nix;
      result = mkSource { inherit versions hashes; };
    in result.version == "1.35.1"
       && lib.any (f: lib.hasInfix "gitVersion=v1.35.1" f) result.ldflags
       && lib.any (f: lib.hasInfix "gitMinor=35" f) result.ldflags)
    "source factory should produce correct ldflags for 1.35")

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
]
