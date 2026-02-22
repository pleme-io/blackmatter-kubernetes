# kubebuilder — SDK for building Kubernetes APIs using CRDs
# NOTE: Uses buildGoModule directly because it needs makeWrapper + go/git/make in PATH
{ pkgs }:
let
  version = "4.10.1";
  src = pkgs.fetchFromGitHub {
    owner = "kubernetes-sigs";
    repo = "kubebuilder";
    rev = "v${version}";
    hash = "sha256-GAHuaUVtdLvyWNeOxu46+IOw2Mf42z3yUjZNiyeE1xs=";
  };
in pkgs.buildGoModule {
  pname = "kubebuilder";
  inherit version src;
  vendorHash = "sha256-NsD2yt73+uRitegezTWwBhF0iMCQ8XhDf6WM/j7kT0o=";
  subPackages = [ "cmd" "." ];
  allowGoReference = true;
  doCheck = false;

  ldflags = [
    "-X sigs.k8s.io/kubebuilder/v4/cmd.kubeBuilderVersion=v${version}"
    "-X sigs.k8s.io/kubebuilder/v4/cmd.gitCommit=unknown"
    "-X sigs.k8s.io/kubebuilder/v4/cmd.buildDate=1970-01-01T00:00:00Z"
  ];

  nativeBuildInputs = [ pkgs.makeWrapper pkgs.installShellFiles ];

  postInstall = ''
    wrapProgram $out/bin/kubebuilder \
      --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.go pkgs.gnumake pkgs.gitMinimal ]}
  '';

  meta = {
    description = "SDK for building Kubernetes APIs using CRDs";
    homepage = "https://github.com/kubernetes-sigs/kubebuilder";
    license = pkgs.lib.licenses.asl20;
    mainProgram = "kubebuilder";
  };
}
