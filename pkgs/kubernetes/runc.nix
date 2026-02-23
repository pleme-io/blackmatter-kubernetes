# runc — OCI container runtime
#
# Low-level container runtime that creates and runs containers.
# Required by containerd. Needs libseccomp for secure computing mode.
{ mkRuntimeComponent, runcVersion, pkgs }:

mkRuntimeComponent {
  pname = "runc";
  version = runcVersion;
  owner = "opencontainers";
  repo = "runc";
  hashes = {
    "1.2.6" = "sha256-XMN+YKdQOQeOLLwvdrC6Si2iAIyyHD5RgZbrOHrQE/g=";
    "1.2.8" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    "1.2.9" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    "1.3.4" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
  vendorHash = null;
  buildInputs = [ pkgs.libseccomp ];
  nativeBuildInputs = [ pkgs.pkg-config ];
  env = { CGO_ENABLED = "1"; };
  subPackages = [ "." ];
  ldflags = [
    "-s" "-w"
    "-X main.version=${runcVersion}"
  ];
  description = "OCI container runtime";
  homepage = "https://github.com/opencontainers/runc";
}
