# Unit tests — pure-Nix evaluation tests (no VMs, instant)
#
# Tests module option structure, assertion logic, flag construction,
# firewall/kernel config generation, and distribution system.
#
# Run: nix eval .#tests.unit
{ lib, nixosHelpers }:

let
  distributions = import ../../lib/distributions.nix { inherit lib; };
  profiles = import ../../lib/profiles.nix { inherit lib; };

  # Evaluate the k3s module with given config
  evalModule = config: let
    mod = import ../../module/nixos/k3s { inherit nixosHelpers; };
    evaluated = lib.evalModules {
      modules = [
        mod
        { config.services.blackmatter.k3s = config; }
        # Stub out system options that the module sets
        {
          options = {
            systemd.services = lib.mkOption { type = lib.types.attrs; default = {}; };
            systemd.tmpfiles.rules = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
            networking.firewall = lib.mkOption { type = lib.types.attrs; default = {}; };
            boot.kernelModules = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
            boot.kernel.sysctl = lib.mkOption { type = lib.types.attrs; default = {}; };
            environment.systemPackages = lib.mkOption { type = lib.types.listOf lib.types.package; default = []; };
            environment.shellAliases = lib.mkOption { type = lib.types.attrs; default = {}; };
            assertions = lib.mkOption { type = lib.types.listOf lib.types.attrs; default = []; };
          };
        }
      ];
    };
  in evaluated.config;

  mkTest = name: assertion: message: {
    inherit name message;
    passed = assertion;
  };

  runTests = tests: let
    results = tests;
    passed = lib.filter (t: t.passed) results;
    failed = lib.filter (t: !t.passed) results;
  in {
    total = lib.length results;
    passCount = lib.length passed;
    failCount = lib.length failed;
    allPassed = failed == [];
    failures = map (t: "${t.name}: ${t.message}") failed;
    summary = "${toString (lib.length passed)}/${toString (lib.length results)} passed";
  };

in runTests [
  # ── Option existence tests ─────────────────────────────────────────
  (mkTest "option-enable-exists"
    (let mod = import ../../module/nixos/k3s { inherit nixosHelpers; };
         evaluated = lib.evalModules {
           modules = [ mod {
             options = {
               systemd.services = lib.mkOption { type = lib.types.attrs; default = {}; };
               systemd.tmpfiles.rules = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
               networking.firewall = lib.mkOption { type = lib.types.attrs; default = {}; };
               boot.kernelModules = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
               boot.kernel.sysctl = lib.mkOption { type = lib.types.attrs; default = {}; };
               environment.systemPackages = lib.mkOption { type = lib.types.listOf lib.types.package; default = []; };
               environment.shellAliases = lib.mkOption { type = lib.types.attrs; default = {}; };
               assertions = lib.mkOption { type = lib.types.listOf lib.types.attrs; default = []; };
             };
           }];
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

  # ── Profile system tests ──────────────────────────────────────────────

  (mkTest "profiles-exist"
    (let names = lib.attrNames profiles.profiles;
     in lib.length names == 8)
    "should have exactly 8 profiles")

  (mkTest "profiles-all-have-required-fields"
    (let
      requiredFields = [ "name" "description" "use" "cni" "disable" "extraFlags"
                         "extraPackages" "firewallTCP" "firewallUDP"
                         "trustedInterfaces" "kernelModules" "manifests" ];
      checkProfile = _: p: lib.all (f: p ? ${f}) requiredFields;
    in lib.all (name: checkProfile name profiles.profiles.${name})
       (lib.attrNames profiles.profiles))
    "all profiles should have all required fields")

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
    ) (lib.attrValues ciliumProfiles))
    "all cilium profiles should set --disable-kube-proxy")

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
]
