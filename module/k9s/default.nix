# modules/home-manager/blackmatter/components/k9s/default.nix
# K9s Kubernetes CLI - TUI for managing Kubernetes clusters
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.blackmatter.components.k9s;

  # K9s config directory path (macOS uses different location)
  k9sConfigPath = if pkgs.stdenv.isDarwin
    then "Library/Application Support/k9s"
    else ".config/k9s";

  # Nord color palette
  nord = {
    # Polar Night
    nord0 = "#2e3440";
    nord1 = "#3b4252";
    nord2 = "#434c5e";
    nord3 = "#4c566a";

    # Snow Storm
    nord4 = "#d8dee9";
    nord5 = "#e5e9f0";
    nord6 = "#eceff4";

    # Frost
    nord7 = "#8fbcbb";
    nord8 = "#88c0d0";
    nord9 = "#81a1c1";
    nord10 = "#5e81ac";

    # Aurora
    nord11 = "#bf616a"; # Red
    nord12 = "#d08770"; # Orange
    nord13 = "#ebcb8b"; # Yellow
    nord14 = "#a3be8c"; # Green
    nord15 = "#b48ead"; # Purple
  };
in {
  options.blackmatter.components.k9s = {
    enable = mkEnableOption "K9s Kubernetes TUI with Nord theme";

    refreshRate = mkOption {
      type = types.int;
      default = 2;
      description = "Refresh rate in seconds";
    };

    headless = mkOption {
      type = types.bool;
      default = false;
      description = "Run in headless mode";
    };

    readOnly = mkOption {
      type = types.bool;
      default = false;
      description = "Run in read-only mode";
    };

    logoless = mkOption {
      type = types.bool;
      default = false;
      description = "Hide K9s logo";
    };

    crumbsless = mkOption {
      type = types.bool;
      default = false;
      description = "Hide breadcrumbs";
    };

    theme = mkOption {
      type = types.enum ["nord" "default"];
      default = "nord";
      description = "K9s theme (nord or default)";
    };
  };

  config = mkIf cfg.enable {
    # K9s is already installed via kubernetes component
    # Just configure it

    # K9s configuration
    home.file."${k9sConfigPath}/config.yaml".text = ''
      k9s:
        # General settings
        refreshRate: ${toString cfg.refreshRate}
        headless: ${if cfg.headless then "true" else "false"}
        readOnly: ${if cfg.readOnly then "true" else "false"}
        logoless: ${if cfg.logoless then "true" else "false"}
        crumbsless: ${if cfg.crumbsless then "true" else "false"}

        # UI settings
        ui:
          enableMouse: true
          headless: ${if cfg.headless then "true" else "false"}
          logoless: ${if cfg.logoless then "true" else "false"}
          crumbsless: ${if cfg.crumbsless then "true" else "false"}
          reactive: false
          noIcons: false
          skin: ${cfg.theme}

        # Logger settings
        logger:
          tail: 100
          buffer: 5000
          sinceSeconds: -1
          fullScreenLogs: false
          textWrap: false
          showTime: false

        # Shell pod settings
        shellPod:
          image: busybox:1.35.0
          namespace: default
          limits:
            cpu: 100m
            memory: 100Mi
    '';

    # Nord skin configuration
    home.file."${k9sConfigPath}/skins/nord.yaml".text = ''
      # Nord theme for K9s - Arctic-inspired elegant dark theme
      k9s:
        body:
          fgColor: "${nord.nord6}"
          bgColor: "${nord.nord0}"
          logoColor: "${nord.nord8}"

        # Prompt
        prompt:
          fgColor: "${nord.nord6}"
          bgColor: "${nord.nord0}"
          suggestColor: "${nord.nord8}"

        # Info section
        info:
          fgColor: "${nord.nord13}"
          sectionColor: "${nord.nord8}"

        # Dialog
        dialog:
          fgColor: "${nord.nord6}"
          bgColor: "${nord.nord1}"
          buttonFgColor: "${nord.nord6}"
          buttonBgColor: "${nord.nord10}"
          buttonFocusFgColor: "${nord.nord0}"
          buttonFocusBgColor: "${nord.nord8}"
          labelFgColor: "${nord.nord12}"
          fieldFgColor: "${nord.nord6}"

        # Frame
        frame:
          border:
            fgColor: "${nord.nord9}"
            focusColor: "${nord.nord8}"
          menu:
            fgColor: "${nord.nord6}"
            keyColor: "${nord.nord8}"
            numKeyColor: "${nord.nord13}"
          crumbs:
            fgColor: "${nord.nord6}"
            bgColor: "${nord.nord3}"
            activeColor: "${nord.nord8}"
          status:
            newColor: "${nord.nord8}"
            modifyColor: "${nord.nord10}"
            addColor: "${nord.nord14}"
            errorColor: "${nord.nord11}"
            highlightColor: "${nord.nord13}"
            killColor: "${nord.nord3}"
            completedColor: "${nord.nord3}"
          title:
            fgColor: "${nord.nord6}"
            bgColor: "${nord.nord3}"
            highlightColor: "${nord.nord8}"
            counterColor: "${nord.nord10}"
            filterColor: "${nord.nord13}"

        # Views
        views:
          charts:
            bgColor: "${nord.nord0}"
            dialBgColor: "${nord.nord1}"
            defaultDialColors:
              - "${nord.nord8}"
              - "${nord.nord11}"
            defaultChartColors:
              - "${nord.nord8}"
              - "${nord.nord11}"

          table:
            fgColor: "${nord.nord6}"
            bgColor: "${nord.nord0}"
            cursorFgColor: "${nord.nord0}"
            cursorBgColor: "${nord.nord8}"
            markColor: "${nord.nord12}"

            header:
              fgColor: "${nord.nord6}"
              bgColor: "${nord.nord3}"
              sorterColor: "${nord.nord8}"

        # YAML viewer
        yaml:
          keyColor: "${nord.nord8}"
          colonColor: "${nord.nord9}"
          valueColor: "${nord.nord6}"

        # Logs
        logs:
          fgColor: "${nord.nord6}"
          bgColor: "${nord.nord0}"
          indicator:
            fgColor: "${nord.nord8}"
            bgColor: "${nord.nord3}"
            toggleOnColor: "${nord.nord14}"
            toggleOffColor: "${nord.nord3}"
    '';

    # Helpful aliases
    programs.zsh.shellAliases = mkIf config.programs.zsh.enable {
      k9 = "k9s";
    };

    programs.bash.shellAliases = mkIf config.programs.bash.enable {
      k9 = "k9s";
    };
  };
}
