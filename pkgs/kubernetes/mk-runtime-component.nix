# Runtime component builder — local helper for blackmatter-kubernetes
#
# Builds a Go runtime component (etcd, containerd, runc, cni-plugins, crictl)
# from upstream source with version-keyed hash maps.
#
# These components share 90% structure but differ in: buildInputs, vendorHash,
# ldflags, subPackages, env, modRoot, completions. This helper captures the
# common pattern.
#
# Usage:
#   mkRuntimeComponent = import ./mk-runtime-component.nix { inherit pkgs; };
#   etcd = mkRuntimeComponent {
#     pname = "etcd-server";
#     version = etcdVersion;
#     owner = "etcd-io"; repo = "etcd";
#     hashes = { "3.5.15" = "sha256-..."; "3.6.7" = "sha256-..."; };
#     vendorHashes = { "3.6.7" = "sha256-..."; };
#     modRoot = "server";
#     description = "etcd distributed key-value store (server)";
#   };
{ pkgs }:

{
  pname,
  version,
  owner,
  repo,
  hashes,
  vendorHash ? null,
  vendorHashes ? null,
  subPackages ? null,
  modRoot ? null,
  ldflags ? [ "-s" "-w" ],
  buildInputs ? [],
  nativeBuildInputs ? [],
  env ? {},
  completions ? null,
  postInstall ? "",
  description,
  homepage ? null,
  mainProgram ? pname,
  platforms ? pkgs.lib.platforms.linux,
}: let
  lib = pkgs.lib;

  src = pkgs.fetchFromGitHub {
    inherit owner repo;
    rev = "v${version}";
    hash = hashes.${version};
  };

  # Shell completion support
  needsInstallShellFiles = completions != null && (completions.install or false);
  completionBuildInputs = lib.optional needsInstallShellFiles pkgs.installShellFiles;

  completionScript = if completions == null || !(completions.install or false) then ""
    else if completions ? command then let
      cmd = completions.command;
    in ''
      installShellCompletion --cmd ${cmd} \
        --bash <($out/bin/${cmd} completion bash) \
        --zsh <($out/bin/${cmd} completion zsh)
    ''
    else "";

  effectiveVendorHash =
    if vendorHashes != null then vendorHashes.${version}
    else vendorHash;

in pkgs.buildGoModule ({
  inherit pname version src ldflags;

  vendorHash = effectiveVendorHash;
  doCheck = false;

  buildInputs = buildInputs;
  nativeBuildInputs = completionBuildInputs ++ nativeBuildInputs;

  postInstall = completionScript + postInstall;

  meta = {
    inherit description mainProgram platforms;
    license = lib.licenses.asl20;
  } // lib.optionalAttrs (homepage != null) { inherit homepage; };
}
// lib.optionalAttrs (subPackages != null) { inherit subPackages; }
// lib.optionalAttrs (modRoot != null) { inherit modRoot; }
// lib.optionalAttrs (env != {}) { inherit env; })
