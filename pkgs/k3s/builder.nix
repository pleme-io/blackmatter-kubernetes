# k3s builder — forked from nixpkgs (d6c71932)
#
# 3-stage Go build:
#   1. k3sCNIPlugins — rancher's patched CNI plugins
#   2a. k3sBundle — main k3s binary with embedded manifests/charts
#   2b. k3sContainerd — containerd-shim-runc-v2 from k3s-io fork
#   3. Final k3s — go generate + go build, wraps with runtime deps
#
# Divergence from nixpkgs:
#   - Removed nixosTests passthru (we run our own tests)
#   - Removed lib.teams.k3s meta (not in nixpkgs teams)
#   - Kept everything else identical for build correctness
lib:
{
  k3sVersion,
  k3sCommit,
  k3sRepoSha256 ? lib.fakeHash,
  k3sVendorHash ? lib.fakeHash,
  k3sRootVersion,
  k3sRootSha256 ? lib.fakeHash,
  chartVersions,
  imagesVersions,
  k3sCNIVersion,
  k3sCNISha256 ? lib.fakeHash,
  containerdVersion,
  containerdSha256 ? lib.fakeHash,
  containerdPackage,
  criCtlVersion,
  updateScript ? null,
  flannelVersion,
  flannelPluginVersion,
  kubeRouterVersion,
  criDockerdVersion,
  helmJobVersion,
}@attrs:

{
  bash,
  bridge-utils,
  btrfs-progs,
  buildGoModule,
  conntrack-tools,
  coreutils,
  ethtool,
  fetchFromGitHub,
  fetchgit,
  fetchurl,
  fetchzip,
  findutils,
  gnugrep,
  gnused,
  go,
  iproute2,
  ipset,
  iptables,
  nftables,
  kmod,
  lib,
  libseccomp,
  makeBinaryWrapper,
  overrideBundleAttrs ? {},
  overrideCniPluginsAttrs ? {},
  overrideContainerdAttrs ? {},
  pkg-config,
  pkgsBuildBuild,
  procps,
  rsync,
  runCommand,
  runc,
  socat,
  sqlite,
  stdenv,
  shadow,
  systemdMinimal,
  util-linuxMinimal,
  yq-go,
  zstd,
  versionCheckHook,
}:

let
  baseMeta = {
    description = "Lightweight Kubernetes distribution";
    license = lib.licenses.asl20;
    homepage = "https://k3s.io";
    platforms = lib.platforms.linux;
    priority = 5;
  };

  versionldflags =
    let
      PKG = "github.com/k3s-io/k3s";
      PKG_CONTAINERD = "github.com/containerd/containerd/v2";
      PKG_CRICTL = "sigs.k8s.io/cri-tools/pkg";
      PKG_K8S_BASE = "k8s.io/component-base";
      PKG_K8S_CLIENT = "k8s.io/client-go/pkg";
      PKG_CNI_PLUGINS = "github.com/containernetworking/plugins";
      PKG_KUBE_ROUTER = "github.com/cloudnativelabs/kube-router/v2";
      PKG_CRI_DOCKERD = "github.com/Mirantis/cri-dockerd";
      PKG_ETCD = "go.etcd.io/etcd";
      PKG_HELM_CONTROLLER = "github.com/k3s-io/helm-controller";
      buildDate = "1970-01-01T01:01:01Z";
    in
    [
      "-X ${PKG}/pkg/version.Version=${k3sVersion}"
      "-X ${PKG}/pkg/version.GitCommit=${lib.substring 0 8 k3sCommit}"
      "-X ${PKG}/pkg/version.UpstreamGolang=go${go.version}"

      "-X ${PKG_K8S_CLIENT}/version.gitVersion=v${k3sVersion}"
      "-X ${PKG_K8S_CLIENT}/version.gitCommit=${k3sCommit}"
      "-X ${PKG_K8S_CLIENT}/version.gitTreeState=clean"
      "-X ${PKG_K8S_CLIENT}/version.buildDate=${buildDate}"

      "-X ${PKG_K8S_BASE}/version.gitVersion=v${k3sVersion}"
      "-X ${PKG_K8S_BASE}/version.gitCommit=${k3sCommit}"
      "-X ${PKG_K8S_BASE}/version.gitTreeState=clean"
      "-X ${PKG_K8S_BASE}/version.buildDate=${buildDate}"

      "-X ${PKG_CRICTL}/version.Version=${criCtlVersion}"

      "-X ${PKG_CONTAINERD}/version.Version=${containerdVersion}"
      "-X ${PKG_CONTAINERD}/version.Package=${containerdPackage}"

      "-X ${PKG_CNI_PLUGINS}/pkg/utils/buildversion.BuildVersion=${k3sCNIVersion}"
      "-X ${PKG_CNI_PLUGINS}/plugins/meta/flannel.Program=flannel"
      "-X ${PKG_CNI_PLUGINS}/plugins/meta/flannel.Version=${flannelPluginVersion}+${flannelVersion}"
      "-X ${PKG_CNI_PLUGINS}/plugins/meta/flannel.Commit=HEAD"
      "-X ${PKG_CNI_PLUGINS}/plugins/meta/flannel.buildDate=${buildDate}"

      "-X ${PKG_KUBE_ROUTER}/pkg/version.Version=${kubeRouterVersion}"
      "-X ${PKG_KUBE_ROUTER}/pkg/version.BuildDate=${buildDate}"

      "-X ${PKG_CRI_DOCKERD}/cmd/version.Version=${criDockerdVersion}"
      "-X ${PKG_CRI_DOCKERD}/cmd/version.GitCommit=HEAD"
      "-X ${PKG_CRI_DOCKERD}/cmd/version.BuildTime=${buildDate}"

      "-X ${PKG_ETCD}/api/v3/version.GitSHA=HEAD"

      "-X ${PKG_HELM_CONTROLLER}/pkg/controllers/chart.DefaultJobImage=rancher/klipper-helm:${helmJobVersion}"
    ];

  traefik = {
    chart = fetchurl chartVersions.traefik;
    name = baseNameOf chartVersions.traefik.url;
  };
  traefik-crd = {
    chart = fetchurl chartVersions.traefik-crd;
    name = baseNameOf chartVersions.traefik-crd.url;
  };

  airgap-images =
    {
      x86_64-linux = fetchurl imagesVersions.airgap-images-amd64-tar-zst;
      aarch64-linux = fetchurl imagesVersions.airgap-images-arm64-tar-zst;
    }
    .${stdenv.hostPlatform.system}
      or (throw "k3s: no airgap images for ${stdenv.hostPlatform.system}");

  k3sRoot = fetchzip {
    url = "https://github.com/k3s-io/k3s-root/releases/download/v${k3sRootVersion}/k3s-root-amd64.tar";
    sha256 = k3sRootSha256;
    stripRoot = false;
  };

  k3sCNIPlugins =
    (buildGoModule rec {
      pname = "k3s-cni-plugins";
      version = k3sCNIVersion;
      vendorHash = null;
      subPackages = [ "." ];
      src = fetchFromGitHub {
        owner = "rancher";
        repo = "plugins";
        rev = "v${version}";
        sha256 = k3sCNISha256;
      };
      postInstall = ''
        mv $out/bin/plugins $out/bin/cni
      '';
      meta = baseMeta // {
        description = "CNI plugins, as patched by rancher for k3s";
      };
    }).overrideAttrs overrideCniPluginsAttrs;

  k3sRepo = fetchgit {
    url = "https://github.com/k3s-io/k3s";
    rev = "v${k3sVersion}";
    sha256 = k3sRepoSha256;
  };

  k3sKillallSh = runCommand "k3s-killall.sh" {} ''
    sed --quiet '/# --- run the install process --/q;p' ${k3sRepo}/install.sh > install.sh

    substituteInPlace install.sh \
      --replace-fail '"''${K3S_DATA_DIR}"' "" \
      --replace-fail '/data/[^/]*/bin/containerd-shim' \
        '/nix/store/[^/]*k3s-containerd[^/]*/bin/containerd-shim'

    remove_matching_line() {
      line_to_delete=$(grep -n "$1" install.sh | cut -d : -f 1 || true)
      if [ -z $line_to_delete ]; then
        echo "failed to find expression \"$1\" in k3s installer script (install.sh)"
        exit 1
      fi
      sed -i "''${line_to_delete}d" install.sh
    }

    remove_matching_line "chmod.*KILLALL_K3S_SH"
    remove_matching_line "chown.*KILLALL_K3S_SH"
    sed -i '$acreate_killall' install.sh
    KILLALL_K3S_SH=$out bash install.sh
  '';

  # Stage 1: Build k3s binaries that get packed into the thick binary
  k3sBundle =
    (buildGoModule {
      pname = "k3s-bin";
      version = k3sVersion;
      src = k3sRepo;
      vendorHash = k3sVendorHash;

      nativeBuildInputs = [ pkg-config ];
      buildInputs = [
        libseccomp
        sqlite.dev
      ];

      subPackages = [ "cmd/server" ];
      ldflags = versionldflags;

      tags = [
        "ctrd"
        "libsqlite3"
        "linux"
      ];

      CGO_CFLAGS = "-DSQLITE_ENABLE_DBSTAT_VTAB=1 -DSQLITE_USE_ALLOCA=1";

      preBuild = ''
        cp -av manifests/* ./pkg/deploy/embed/
        mkdir -p ./pkg/static/embed/charts/
        cp -v ${traefik.chart} ./pkg/static/embed/charts/${traefik.name}
        cp -v ${traefik-crd.chart} ./pkg/static/embed/charts/${traefik-crd.name}
      '';

      postInstall = ''
        mv $out/bin/server $out/bin/k3s
        pushd $out
        ln -s k3s ./bin/containerd
        ln -s k3s ./bin/crictl
        ln -s k3s ./bin/ctr
        ln -s k3s ./bin/k3s-agent
        ln -s k3s ./bin/k3s-certificate
        ln -s k3s ./bin/k3s-completion
        ln -s k3s ./bin/k3s-etcd-snapshot
        ln -s k3s ./bin/k3s-secrets-encrypt
        ln -s k3s ./bin/k3s-server
        ln -s k3s ./bin/k3s-token
        ln -s k3s ./bin/kubectl
        popd
      '';

      meta = baseMeta // {
        description = "Binaries packaged into the final k3s binary";
      };
    }).overrideAttrs overrideBundleAttrs;

  # Stage 2: containerd-shim-runc-v2 from k3s fork
  k3sContainerd =
    (buildGoModule {
      pname = "k3s-containerd";
      version = containerdVersion;
      src = fetchFromGitHub {
        owner = "k3s-io";
        repo = "containerd";
        rev = "v${containerdVersion}";
        sha256 = containerdSha256;
      };
      vendorHash = null;
      buildInputs = [ btrfs-progs ];
      subPackages = [ "cmd/containerd-shim-runc-v2" ];
      ldflags = versionldflags;
    }).overrideAttrs overrideContainerdAttrs;

in
# Stage 3: Final thick k3s binary
buildGoModule (finalAttrs: {
  pname = "k3s";
  version = k3sVersion;
  pos = builtins.unsafeGetAttrPos "k3sVersion" attrs;

  tags = [
    "libsqlite3"
    "linux"
    "ctrd"
  ];
  src = k3sRepo;
  vendorHash = k3sVendorHash;

  postPatch = ''
    substituteInPlace scripts/package-cli \
      --replace-fail '"$LDFLAGS $STATIC" -o' \
                '"$LDFLAGS" -o'

    substituteInPlace scripts/version.sh \
      --replace-fail \
        "go list -mod=readonly -m -f '{{if .Replace}}{{.Replace.Version}}{{else}}{{.Version}}{{end}}' \$1" \
        "go list -mod=readonly -e -m -f '{{if .Replace}}{{.Replace.Version}}{{else}}{{.Version}}{{end}}' \$1"

    substituteInPlace scripts/version.sh \
      --replace-quiet \
        'VERSION_GOLANG="go"$(curl -sL "https://raw.githubusercontent.com''${PKG_KUBERNETES_K3S/github.com/}/refs/tags/''${VERSION_K8S_K3S}/.go-version")' \
        ""
  '';

  k3sRuntimeDeps = [
    kmod
    socat
    iptables
    nftables
    iproute2
    ipset
    bridge-utils
    ethtool
    util-linuxMinimal
    conntrack-tools
    runc
    bash
    shadow
  ];

  k3sKillallDeps = [
    bash
    systemdMinimal
    procps
    coreutils
    gnugrep
    findutils
    gnused
  ];

  buildInputs = finalAttrs.k3sRuntimeDeps;

  nativeBuildInputs = [
    makeBinaryWrapper
    rsync
    yq-go
    zstd
  ];

  propagatedBuildInputs = [
    k3sCNIPlugins
    k3sContainerd
    k3sBundle
  ];

  buildPhase = ''
    runHook preBuild
    patchShebangs ./scripts/package-cli ./scripts/download ./scripts/build-upload

    mkdir -p ./bin/aux
    rsync -a --no-perms ${k3sBundle}/bin/ ./bin/
    ln -vsf ${k3sCNIPlugins}/bin/cni ./bin/cni
    ln -vsf ${k3sContainerd}/bin/containerd-shim-runc-v2 ./bin
    rsync -a --no-perms --chmod u=rwX ${k3sRoot}/etc/ ./etc/

    export ARCH=$GOARCH
    export TAG="v${k3sVersion}"
    export GITHUB_SHA="${k3sCommit}"

    ./scripts/package-cli
    mkdir -p $out/bin
    runHook postBuild
  '';

  doCheck = false;

  installPhase = ''
    runHook preInstall
    install -m 0755 dist/artifacts/k3s* -D $out/bin/k3s
    wrapProgram $out/bin/k3s \
      --prefix PATH : ${lib.makeBinPath finalAttrs.k3sRuntimeDeps} \
      --prefix PATH : "$out/bin"
    ln -s $out/bin/k3s $out/bin/kubectl
    ln -s $out/bin/k3s $out/bin/crictl
    ln -s $out/bin/k3s $out/bin/ctr
    install -m 0755 ${k3sKillallSh} -D $out/bin/k3s-killall.sh
    wrapProgram $out/bin/k3s-killall.sh \
      --prefix PATH : ${lib.makeBinPath (finalAttrs.k3sRuntimeDeps ++ finalAttrs.k3sKillallDeps)}
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru = {
    inherit
      airgap-images
      k3sCNIPlugins
      k3sContainerd
      k3sRepo
      k3sRoot
      k3sBundle
      ;
  }
  // (lib.mapAttrs (_: value: fetchurl value) imagesVersions);

  meta = baseMeta // {
    mainProgram = "k3s";
  };
})
