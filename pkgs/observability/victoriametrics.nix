# VictoriaMetrics — High-performance time series database
# NOTE: Uses buildGoModule directly due to complex postPatch requirements
{ pkgs }:
let
  version = "1.136.0";
  src = pkgs.fetchFromGitHub {
    owner = "VictoriaMetrics";
    repo = "VictoriaMetrics";
    rev = "v${version}";
    hash = "sha256-mYFZ2swaRHYfKeL5r4NTmynQ5sOHcHMPJlChKXQsreA=";
  };
in pkgs.buildGoModule {
  pname = "victoriametrics";
  inherit version src;
  vendorHash = null;

  subPackages = [
    "app/vmctl"
    "app/vmagent"
    "app/vmalert"
    "app/vmalert-tool"
    "app/vmauth"
    "app/vmbackup"
    "app/vmrestore"
  ];

  env.CGO_ENABLED = "0";

  ldflags = [
    "-s" "-w"
    "-X github.com/VictoriaMetrics/VictoriaMetrics/lib/buildinfo.Version=${version}"
  ];

  # Remove the embedded web UI Go module and relax Go version constraints
  postPatch = ''
    rm -rf app/vmui/packages/vmui/web
    # Ensure go.mod doesn't enforce a toolchain version we don't have
    sed -i 's/^toolchain .*$//' go.mod || true
  '';

  doCheck = false;

  meta = {
    description = "High-performance time series database and monitoring solution";
    homepage = "https://victoriametrics.com/";
    license = pkgs.lib.licenses.asl20;
    mainProgram = "vmctl";
  };
}
