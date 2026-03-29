{ lib, pkgs, config, ... }:

with lib;

let
  cfg = config.blackmatter.components.kubernetes.kind;

  # Per-cluster config type
  clusterModule = types.submodule {
    options = {
      nodes = mkOption {
        type = types.listOf (types.submodule {
          options = {
            role = mkOption {
              type = types.enum [ "control-plane" "worker" ];
              default = "control-plane";
              description = "Node role in the kind cluster.";
            };
            image = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Node image override (e.g. kindest/node:v1.31.0).";
            };
            extraPortMappings = mkOption {
              type = types.listOf (types.submodule {
                options = {
                  containerPort = mkOption { type = types.int; };
                  hostPort = mkOption { type = types.int; };
                  protocol = mkOption {
                    type = types.enum [ "TCP" "UDP" "SCTP" ];
                    default = "TCP";
                  };
                };
              });
              default = [];
              description = "Extra port mappings for this node.";
            };
          };
        });
        default = [{ role = "control-plane"; }];
        description = "List of nodes in the cluster.";
      };

      extraConfig = mkOption {
        type = types.lines;
        default = "";
        description = "Additional raw YAML appended to the kind config.";
      };
    };
  };

  # Generate kind cluster YAML from structured config
  mkClusterYaml = name: cluster: let
    nodeYaml = node: let
      imageLine = optionalString (node.image != null) "\n  image: ${node.image}";
      portLines = concatMapStringsSep "\n" (m: ''
        - containerPort: ${toString m.containerPort}
          hostPort: ${toString m.hostPort}
          protocol: ${m.protocol}'') node.extraPortMappings;
      portBlock = optionalString (node.extraPortMappings != []) "\n  extraPortMappings:\n${portLines}";
    in "- role: ${node.role}${imageLine}${portBlock}";
  in ''
    kind: Cluster
    apiVersion: kind.x-k8s.io/v1alpha4
    name: ${name}
    nodes:
    ${concatMapStringsSep "\n" nodeYaml cluster.nodes}
  '' + optionalString (cluster.extraConfig != "") cluster.extraConfig;

in
{
  options.blackmatter.components.kubernetes.kind = {
    enable = mkEnableOption "Enable kind (Kubernetes IN Docker) cluster management.";

    clusters = mkOption {
      type = types.attrsOf clusterModule;
      default = {};
      description = "Named kind cluster configurations written to ~/.config/kind/<name>.yaml.";
    };

    client.enable = mkEnableOption "Enable client tools and KUBECONFIG management for kind.";

    client.tools = mkOption {
      type = types.listOf types.str;
      default = [ "kubectl" "k9s" ];
      description = "List of client tools to install for interacting with the kind cluster.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      (pkgs.${"blackmatter-kind"} or pkgs.kind)
    ] ++ lib.optionals cfg.client.enable (map (tool: pkgs.${tool}) cfg.client.tools);

    # Write cluster config files to ~/.config/kind/<name>.yaml
    xdg.configFile = mapAttrs' (name: cluster:
      nameValuePair "kind/${name}.yaml" {
        text = mkClusterYaml name cluster;
      }
    ) cfg.clusters;

    # Shell aliases for kind cluster management
    programs.zsh.shellAliases = mkIf config.programs.zsh.enable {
      kcc = "kind create cluster --config";
      kdc = "kind delete cluster --name";
      kgc = "kind get clusters";
    };

    programs.bash.shellAliases = mkIf config.programs.bash.enable {
      kcc = "kind create cluster --config";
      kdc = "kind delete cluster --name";
      kgc = "kind get clusters";
    };
  };
}
