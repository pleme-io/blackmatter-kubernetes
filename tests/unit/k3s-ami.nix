# Unit tests for the typed k3s-ami module + lib helpers.
#
# Pure-Nix evaluation tests — no VM, instant. Validates lib helpers
# produce the right derived names + SSM keys for every (variant, arch,
# platform) tuple, and that deriveAmi composes correctly.
#
# Run: nix eval .#tests.x86_64-linux.k3s-ami
{ lib, testHelpers }:

let
  inherit (testHelpers) mkTest runTests;
  k = import ../../lib/k3s-ami.nix { inherit lib; };
in
runTests [
  # ── lib.k3s-ami.systemFor ────────────────────────────────────────
  (mkTest "systemFor:x86_64"
    (k.systemFor "x86_64" == "x86_64-linux")
    "x86_64 should map to x86_64-linux")
  (mkTest "systemFor:aarch64"
    (k.systemFor "aarch64" == "aarch64-linux")
    "aarch64 should map to aarch64-linux")

  # ── lib.k3s-ami.defaultInstanceTypeFor ───────────────────────────
  (mkTest "defaultInstanceTypeFor:x86_64"
    (k.defaultInstanceTypeFor "x86_64" == "t3.medium")
    "x86_64 default cluster instance is t3.medium")
  (mkTest "defaultInstanceTypeFor:aarch64"
    (k.defaultInstanceTypeFor "aarch64" == "t4g.medium")
    "aarch64 default cluster instance is t4g.medium")

  # ── lib.k3s-ami.amiNameFor ───────────────────────────────────────
  (mkTest "amiNameFor:pleme-x86_64-ssm-runtime"
    (k.amiNameFor { variant = "ssm-runtime"; architecture = "x86_64"; platform = "pleme"; }
     == "nixos-k3s-ssm-runtime-x86_64-pleme")
    "AMI name template should be nixos-k3s-<variant>-<arch>-<platform>")
  (mkTest "amiNameFor:akeyless-aarch64-kindling-init"
    (k.amiNameFor { variant = "kindling-init"; architecture = "aarch64"; platform = "akeyless-dev"; }
     == "nixos-k3s-kindling-init-aarch64-akeyless-dev")
    "AMI name handles all variant+arch+platform combos")

  # ── lib.k3s-ami.ssmTargetFor ─────────────────────────────────────
  (mkTest "ssmTargetFor:pleme"
    (k.ssmTargetFor "pleme" == "/pangea/pleme/k3s-ami-id")
    "SSM target should be /pangea/<platform>/k3s-ami-id")
  (mkTest "ssmTargetFor:akeyless-dev"
    (k.ssmTargetFor "akeyless-dev" == "/pangea/akeyless-dev/k3s-ami-id")
    "SSM target adapts to platform name")

  # ── lib.k3s-ami.deriveAmi composition ────────────────────────────
  (mkTest "deriveAmi:pleme-x86_64-ssm-runtime"
    (k.deriveAmi { variant = "ssm-runtime"; architecture = "x86_64"; platform = "pleme"; }
     == { name = "nixos-k3s-ssm-runtime-x86_64-pleme";
          ssmTarget = "/pangea/pleme/k3s-ami-id";
          instanceType = "t3.medium"; })
    "deriveAmi composes name + ssmTarget + instanceType correctly")
  (mkTest "deriveAmi:akeyless-aarch64-kindling-init"
    (k.deriveAmi { variant = "kindling-init"; architecture = "aarch64"; platform = "akeyless-dev"; }
     == { name = "nixos-k3s-kindling-init-aarch64-akeyless-dev";
          ssmTarget = "/pangea/akeyless-dev/k3s-ami-id";
          instanceType = "t4g.medium"; })
    "deriveAmi composes correctly across variant + arch")
]
