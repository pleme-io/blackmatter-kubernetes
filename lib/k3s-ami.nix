# Helpers for the typed k3s-ami module.
#
# Every helper is a pure function of the typed declaration so callers
# (kindling-profiles bake apps, platform-packer, pleme.yaml consumers)
# all derive the same outputs from the same inputs — no hand-wired
# duplication.

{ lib }:

with lib;

let
  # ── Architecture → NixOS system string ──────────────────────────────
  systemFor = arch: {
    "x86_64"  = "x86_64-linux";
    "aarch64" = "aarch64-linux";
  }.${arch};

  # ── Architecture → default cluster instance type ────────────────────
  # Picked to match the K3s memory-pressure tests in pleme.yaml's
  # original instance_type comment block.
  defaultInstanceTypeFor = arch: {
    "x86_64"  = "t3.medium";
    "aarch64" = "t4g.medium";
  }.${arch};

  # ── AMI name convention ─────────────────────────────────────────────
  # nixos-k3s-${variant}-${architecture}-${platform}
  #
  # Distinct prefix per (variant, arch, platform) tuple so the
  # ami-forge reaper (groups by name-prefix-without-timestamp)
  # doesn't conflate them. Older callers used "nixos-k3s-cloud-server"
  # which collapsed every variant into one reaper group.
  amiNameFor = { variant, architecture, platform }:
    "nixos-k3s-${variant}-${architecture}-${platform}";

  # ── SSM target convention ───────────────────────────────────────────
  # /pangea/${platform}/k3s-ami-id
  #
  # platform-k3s's launch template resolves this exact path:
  #   image_id = "resolve:ssm:/pangea/${platform}/k3s-ami-id"
  ssmTargetFor = platform: "/pangea/${platform}/k3s-ami-id";

in {
  inherit systemFor defaultInstanceTypeFor amiNameFor ssmTargetFor;

  # ── AMI metadata derivation ─────────────────────────────────────────
  # Takes the user-facing typed declaration (variant + architecture +
  # platform) and returns the convention-derived ami{} attrset that
  # the module's `services.blackmatter.k3s-ami.ami` option expects.
  # Callers use this when they want defaults but haven't set ami.* by
  # hand:
  #
  #   services.blackmatter.k3s-ami = {
  #     enable = true;
  #     variant = "ssm-runtime";
  #     architecture = "x86_64";
  #     platform = "pleme";
  #     ami = bmk.lib.k3s-ami.deriveAmi { variant = "ssm-runtime";
  #                                       architecture = "x86_64";
  #                                       platform = "pleme"; };
  #   };
  deriveAmi = { variant, architecture, platform }: {
    name = amiNameFor { inherit variant architecture platform; };
    ssmTarget = ssmTargetFor platform;
    instanceType = defaultInstanceTypeFor architecture;
  };

  # ── nixosSystem builder ─────────────────────────────────────────────
  # Returns a complete nixosSystem given a typed k3s-ami declaration
  # plus the dependency injections the module needs (nixpkgs ref,
  # extra modules, overlay sources). Single source of truth — both
  # the kindling-profiles and platform-packer bake paths consume this.
  #
  # Args:
  #   nixpkgs            : flake input; used for nixpkgs.lib.nixosSystem
  #   k3sAmiModule       : the module path (./module/nixos/k3s-ami)
  #   blackmatterModule  : nixosModules.blackmatter aggregator. Already
  #                        transitively imports nixosModules.fluxcd +
  #                        nixosModules.k3s; do NOT also pass them here
  #                        (would yield duplicate option declarations).
  #   tataraOverlay      : inputs.tatara-lisp.overlays.default
  #   declaration        : { variant, architecture, platform, runtime,
  #                          bootstrap }
  #   extraModules       : per-platform additions (rare)
  #
  # Returns: nixosSystem, ready to evaluate config.system.build.toplevel.
  mkK3sAmiSystem = {
    nixpkgs,
    k3sAmiModule,
    blackmatterModule,
    tataraOverlay,
    declaration,
    extraModules ? [],
  }: nixpkgs.lib.nixosSystem {
    system = systemFor declaration.architecture;
    modules = [
      blackmatterModule
      k3sAmiModule
      ({ ... }: {
        nixpkgs.overlays = [ tataraOverlay ];
        services.blackmatter.k3s-ami = {
          enable = true;
          inherit (declaration) variant architecture platform;
          runtime = declaration.runtime or { cni = "flannel"; cilium.version = "1.16.4"; };
          bootstrap = declaration.bootstrap or {
            fluxcd = { enable = false; source = null; sopsPath = null; };
            imagePullSecrets = [];
          };
          ami = declaration.ami or (
            # auto-derive from variant+architecture+platform
            let d = { inherit (declaration) variant architecture platform; };
            in {
              name         = amiNameFor d;
              ssmTarget    = ssmTargetFor declaration.platform;
              instanceType = defaultInstanceTypeFor declaration.architecture;
            }
          );
        };
      })
    ] ++ extraModules;
  };
}
