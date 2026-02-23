# runc — OCI container runtime
#
# Low-level container runtime that creates and runs containers.
# Required by containerd. Needs libseccomp for secure computing mode.
{ pkgs, runcVersion }:

let
  version = runcVersion;

  # Hash map per runc version (placeholder hashes for untested versions)
  hashes = {
    "1.2.6" = "sha256-XMN+YKdQOQeOLLwvdrC6Si2iAIyyHD5RgZbrOHrQE/g=";
    "1.2.8" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    "1.2.9" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    "1.3.4" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  src = pkgs.fetchFromGitHub {
    owner = "opencontainers";
    repo = "runc";
    rev = "v${version}";
    hash = hashes.${version};
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
