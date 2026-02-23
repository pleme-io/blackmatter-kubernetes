# runc — OCI container runtime
#
# Low-level container runtime that creates and runs containers.
# Required by containerd. Needs libseccomp for secure computing mode.
{ pkgs, runcVersion }:

let
  version = runcVersion;
  src = pkgs.fetchFromGitHub {
    owner = "opencontainers";
    repo = "runc";
    rev = "v${version}";
    hash = "sha256-XMN+YKdQOQeOLLwvdrC6Si2iAIyyHD5RgZbrOHrQE/g=";
  };
in pkgs.buildGoModule {
  pname = "runc";
  inherit version src;

  vendorHash = null; # vendored in-tree

  buildInputs = [ pkgs.libseccomp ];
  nativeBuildInputs = [ pkgs.pkg-config ];

  # runc needs CGO for libseccomp
  env.CGO_ENABLED = "1";

  ldflags = [
    "-s" "-w"
    "-X main.version=${version}"
  ];

  subPackages = [ "." ];
  doCheck = false;

  meta = {
    description = "OCI container runtime";
    homepage = "https://github.com/opencontainers/runc";
    license = pkgs.lib.licenses.asl20;
    mainProgram = "runc";
    platforms = pkgs.lib.platforms.linux;
  };
}
