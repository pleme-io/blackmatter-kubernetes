# services.blackmatter.k3s-ami — typed K3s AMI option surface.
#
# Single source of truth for "produce a K3s AMI". Subsumes the matrix
# of (variant × architecture × platform × bootstrap-content) that was
# previously hand-wired across:
#   - kindling-profiles/profiles/k3s-cloud-server-ssm/
#   - kindling-profiles/profiles/k3s-cloud-server/   (legacy, full FedRAMP)
#   - kindling-profiles/flake.nix nixosConfigurations.{ami-builder,
#     k3s-cloud-server-ssm,k8s-builder,...}
#   - pangea-architectures/workspaces/platform-packer/{flake.nix,*.rb}
#   - pangea-architectures/platforms/<platform>.yaml `packer.ami_types`
#
# Authoring shape (NixOS):
#   services.blackmatter.k3s-ami = {
#     enable = true;
#     variant = "ssm-runtime";        # | "kindling-init"
#     architecture = "x86_64";        # | "aarch64"  -- fleet default x86_64
#     platform = "pleme";             # drives /pangea/${platform}/k3s-ami-id
#     runtime = {
#       cni = "flannel";              # | "cilium"
#       fluxcd = {
#         enable = true;
#         source = { url=...; branch="main"; path="./clusters/<c>"; };
#         sopsPath = "github/pleme-io/flux-cd-k8s-readonly";
#       };
#       imagePullSecrets = [{
#         name = "ghcr-pull-secret"; namespace = "openclaw";
#         registry = "ghcr.io"; username = "drzzln";
#         sopsPath = "github/pleme-io/token";
#       }];
#     };
#   };
#
# What this module emits (when consumed by a NixOS configuration):
#   * services.k3s configuration (gated on /var/lib/k3s-bootstrap-complete)
#   * systemd.services.k3s-bootstrap (tatara-script first-boot)
#   * services.blackmatter.fluxcd config (when runtime.fluxcd.enable)
#   * Required runtime tooling (k3s, awscli2, tatara-script)
#
# What this module DOES NOT emit (those live one level up — the
# bake driver derives them from the same option values):
#   * AMI name, SSM target, instance-type defaults — see lib/ami-metadata.nix
#   * The actual nixosSystem (= bake target)             — see lib/mk-k3s-ami-system.nix

{ lib }:

with lib;
with lib.types;

let
  # ── Variant: bootstrap pattern ──────────────────────────────────────
  # ssm-runtime  : generic AMI; per-cluster runtime values flow from
  #                /pangea/<platform>/k3s/<cluster>/* SSM at first-boot
  #                via tatara-script (k3s-bootstrap.tlisp). One AMI
  #                serves every cluster on the platform.
  # kindling-init: legacy. Cluster-specific cluster-config.json baked
  #                into the AMI; kindling-init.service replays it.
  #                Kept for backwards-compat with akeyless-dev-cluster /
  #                seph workspaces; new clusters MUST use ssm-runtime.
  variantType = enum [ "ssm-runtime" "kindling-init" ];

  # ── Architecture ────────────────────────────────────────────────────
  # Fleet default is x86_64 — the AMI bake flow + cluster instance
  # type matrix are most stable here. aarch64 reserved for explicit
  # power-efficient workloads (future).
  architectureType = enum [ "x86_64" "aarch64" ];

  # ── CNI ─────────────────────────────────────────────────────────────
  # flannel: K3s default (vxlan + kube-proxy). Stable on single-node
  #          t3.medium. Use this until the cluster is otherwise validated.
  # cilium : eBPF, Hubble, kube-proxy replacement. Full impl preserved
  #          in k3s-bootstrap.tlisp but not yet stable on small nodes.
  cniType = enum [ "flannel" "cilium" ];

  # Sub-submodule: an FluxCD git source.
  fluxcdSourceType = submodule {
    options = {
      url = mkOption {
        type = str;
        description = "FluxCD source git URL (e.g. https://github.com/pleme-io/k8s.git).";
      };
      branch = mkOption {
        type = str;
        default = "main";
        description = "Branch name FluxCD reconciles from.";
      };
      path = mkOption {
        type = str;
        description = "Path inside the repo for the cluster's manifests (e.g. ./clusters/pleme-dev).";
      };
      interval = mkOption {
        type = str;
        default = "1m0s";
        description = "GitRepository reconcile interval.";
      };
    };
  };

  # Sub-submodule: an image-pull-secret materialization request.
  # Pangea reads sopsPath at apply time, base64s `username:pat`, builds
  # {"auths":{registry:{"auth":...}}}, pushes the dockerconfigjson as
  # SecureString to /pangea/<platform>/k3s/<cluster>/imagepullsecrets/<name>/.
  # k3s-bootstrap.tlisp at first-boot reads each + writes a Namespace +
  # Secret manifest pair to K3s's auto-apply dir.
  imagePullSecretType = submodule {
    options = {
      name = mkOption {
        type = str;
        description = "Secret name inside the cluster (e.g. ghcr-pull-secret).";
      };
      namespace = mkOption {
        type = str;
        description = "Target namespace. The bootstrap also writes the Namespace itself if missing.";
      };
      registry = mkOption {
        type = str;
        description = "Registry hostname (e.g. ghcr.io).";
      };
      username = mkOption {
        type = str;
        description = ''
          Registry username — by GHCR convention, the GitHub user who
          minted the PAT, not the org. Token itself is org-scoped via
          fine-grained PAT permissions.
        '';
      };
      sopsPath = mkOption {
        type = str;
        description = ''
          SOPS path that resolves to the registry PAT/password.
          Pangea::Secrets.resolve reads it at apply time.
        '';
      };
    };
  };

  bootstrapType = submodule {
    options = {
      fluxcd = mkOption {
        type = submodule {
          options = {
            enable = mkEnableOption "FluxCD GitOps bootstrap";
            source = mkOption {
              type = nullOr fluxcdSourceType;
              default = null;
              description = "Git source (when enable=true).";
            };
            sopsPath = mkOption {
              type = nullOr str;
              default = null;
              description = ''
                SOPS path resolving to a GitHub PAT with `Contents:Read`
                on the source repo. Pangea pushes to SSM as SecureString;
                bootstrap reads + writes /var/lib/k3s-fluxcd/github-token.
              '';
            };
          };
        };
        default = { enable = false; source = null; sopsPath = null; };
        description = "FluxCD bootstrap configuration.";
      };

      imagePullSecrets = mkOption {
        type = listOf imagePullSecretType;
        default = [];
        description = ''
          List of dockerconfigjson Secrets to materialize at first-boot.
          Each entry causes Pangea to push 3 SSM keys (namespace,
          registry, dockerconfigjson) plus a roster index; k3s-bootstrap
          iterates and writes Namespace+Secret pairs into K3s's auto-apply
          dir.
        '';
      };
    };
  };

  amiType = submodule {
    options = {
      name = mkOption {
        type = str;
        description = ''
          AMI name. Convention:
            nixos-k3s-${variant}-${architecture}-${platform}
          Distinct per (variant, arch, platform) so the ami-forge reaper
          (groups by name-prefix) doesn't collapse them.
        '';
      };
      ssmTarget = mkOption {
        type = str;
        description = ''
          SSM key the bake promotes to + the cluster launch template
          resolves from. Convention: /pangea/${platform}/k3s-ami-id.
        '';
      };
      instanceType = mkOption {
        type = str;
        description = ''
          Default cluster instance type. Architecture-derived default:
          x86_64 → t3.medium ; aarch64 → t4g.medium. Override per-cluster.
        '';
      };
    };
  };

in {
  options.services.blackmatter.k3s-ami = {
    enable = mkEnableOption "Blackmatter K3s AMI module — typed K3s AMI production surface";

    variant = mkOption {
      type = variantType;
      default = "ssm-runtime";
      description = ''
        Bootstrap pattern. ssm-runtime is the canonical fleet default;
        kindling-init kept only for legacy akeyless-dev-cluster / seph
        workspaces.
      '';
    };

    architecture = mkOption {
      type = architectureType;
      default = "x86_64";
      description = ''
        Target CPU architecture. x86_64 is the fleet default and the
        only architecture currently exercised end-to-end by the bake
        + cluster-launch matrix. aarch64 reserved for future workloads.
      '';
    };

    platform = mkOption {
      type = str;
      description = ''
        Platform name (e.g. "pleme"). Drives every per-platform output:
        AMI name suffix, SSM target, instance tag pleme:k3s:ssm-prefix.
        Must match the platform yaml under pangea-architectures/platforms/.
      '';
    };

    runtime = mkOption {
      type = submodule {
        options = {
          cni = mkOption {
            type = cniType;
            default = "flannel";
            description = "CNI selector (passed to the bootstrap script via SSM).";
          };
          cilium = mkOption {
            type = submodule {
              options = {
                version = mkOption {
                  type = str;
                  default = "1.16.4";
                  description = "Cilium chart version (only used when cni=cilium).";
                };
              };
            };
            default = { version = "1.16.4"; };
            description = "Cilium-specific knobs.";
          };
        };
      };
      default = { cni = "flannel"; cilium.version = "1.16.4"; };
      description = "Cluster runtime knobs that flow into the bootstrap.";
    };

    bootstrap = mkOption {
      type = bootstrapType;
      default = {
        fluxcd = { enable = false; source = null; sopsPath = null; };
        imagePullSecrets = [];
      };
      description = ''
        First-boot bootstrap content. The actual values flow from SSM
        at boot time; this attrset captures *which* slots are populated
        so the consumer (Pangea workspace) knows what to push.
      '';
    };

    ami = mkOption {
      type = amiType;
      description = ''
        AMI metadata. Defaults are derived from variant+architecture+platform
        in the consuming flake; you only override here if you need a
        non-conventional name or SSM key.
      '';
    };
  };
}
