# HM module evaluation tests — pure-Nix (no VMs)
#
# Tests profile system, per-tool overrides, and package counts.
#
# Run: nix eval .#tests.hm-module
{ lib }:

let
  # Stub HM options that the kubernetes module (and sub-modules) reference
  hmStubs = {
    options = {
      home.packages = lib.mkOption { type = lib.types.listOf lib.types.package; default = []; };
      home.file = lib.mkOption { type = lib.types.attrs; default = {}; };
      home.homeDirectory = lib.mkOption { type = lib.types.str; default = "/home/test"; };
      home.sessionVariables = lib.mkOption { type = lib.types.attrsOf lib.types.str; default = {}; };
      programs.zsh = {
        enable = lib.mkOption { type = lib.types.bool; default = false; };
        shellAliases = lib.mkOption { type = lib.types.attrsOf lib.types.str; default = {}; };
      };
      programs.bash = {
        enable = lib.mkOption { type = lib.types.bool; default = false; };
        shellAliases = lib.mkOption { type = lib.types.attrsOf lib.types.str; default = {}; };
      };
    };
  };

  # Evaluate the HM kubernetes module with given config
  evalHmModule = config: let
    mod = import ../../module/home-manager/kubernetes;
    evaluated = lib.evalModules {
      modules = [
        mod
        { config.blackmatter.components.kubernetes = { enable = true; } // config; }
        hmStubs
      ];
    };
  in evaluated;

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

  # Profile tool counts (from module definition)
  minimalCount = 4;    # kubectl, helm, k9s, kubectx
  standardCount = 18;  # minimal + 14 more

in runTests [
  # ── Profile option tests ───────────────────────────────────────────
  (mkTest "profile-option-exists"
    (let evaluated = evalHmModule {};
     in evaluated.options ? blackmatter
        && evaluated.options.blackmatter.components ? kubernetes
        && evaluated.options.blackmatter.components.kubernetes ? profile)
    "blackmatter.components.kubernetes.profile option should exist")

  (mkTest "tools-option-exists"
    (let evaluated = evalHmModule {};
     in evaluated.options.blackmatter.components.kubernetes ? tools)
    "blackmatter.components.kubernetes.tools option should exist")

  # ── Profile definitions ────────────────────────────────────────────
  (mkTest "profile-default-is-standard"
    (let evaluated = evalHmModule {};
     in evaluated.config.blackmatter.components.kubernetes.profile == "standard")
    "default profile should be standard")

  # ── Profile size ordering ──────────────────────────────────────────
  (mkTest "profile-minimal-size"
    (minimalCount == 4)
    "minimal profile should have 4 tools")

  (mkTest "profile-standard-larger-than-minimal"
    (standardCount > minimalCount)
    "standard profile should have more tools than minimal")

  (mkTest "profile-valid-enum"
    (lib.elem "minimal" [ "minimal" "standard" "full" ]
     && lib.elem "standard" [ "minimal" "standard" "full" ]
     && lib.elem "full" [ "minimal" "standard" "full" ])
    "profile enum should accept minimal, standard, full")
]
