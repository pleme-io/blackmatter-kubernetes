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

  # Nord color palette — canonical hex values from nordtheme.com
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
    # K9s configuration
    home.file."${k9sConfigPath}/config.yaml".text = ''
      k9s:
        refreshRate: ${toString cfg.refreshRate}
        headless: ${if cfg.headless then "true" else "false"}
        readOnly: ${if cfg.readOnly then "true" else "false"}
        logoless: ${if cfg.logoless then "true" else "false"}
        crumbsless: ${if cfg.crumbsless then "true" else "false"}
        ui:
          enableMouse: true
          headless: ${if cfg.headless then "true" else "false"}
          logoless: ${if cfg.logoless then "true" else "false"}
          crumbsless: ${if cfg.crumbsless then "true" else "false"}
          reactive: false
          noIcons: false
          skin: ${cfg.theme}
        logger:
          tail: 100
          buffer: 5000
          sinceSeconds: -1
          fullScreenLogs: false
          textWrap: false
          showTime: false
        shellPod:
          image: busybox:1.35.0
          namespace: default
          limits:
            cpu: 100m
            memory: 100Mi
    '';

    # Nord skin — full spec coverage for k9s 0.50+
    # Uses "default" for bgColor where possible (inherits terminal background,
    # enables transparency with compositors like Ghostty/Kitty).
    # True Nord palette hex values throughout.
    home.file."${k9sConfigPath}/skins/nord.yaml".text = ''
      k9s:
        body:
          fgColor: "${nord.nord4}"
          bgColor: default
          logoColor: "${nord.nord8}"
        prompt:
          fgColor: "${nord.nord4}"
          bgColor: "${nord.nord0}"
          suggestColor: "${nord.nord12}"
        info:
          fgColor: "${nord.nord9}"
          sectionColor: "${nord.nord4}"
        dialog:
          fgColor: "${nord.nord4}"
          bgColor: default
          buttonFgColor: "${nord.nord4}"
          buttonBgColor: "${nord.nord15}"
          buttonFocusFgColor: "${nord.nord13}"
          buttonFocusBgColor: "${nord.nord9}"
          labelFgColor: "${nord.nord12}"
          fieldFgColor: "${nord.nord4}"
        frame:
          border:
            fgColor: "${nord.nord3}"
            focusColor: "${nord.nord8}"
          menu:
            fgColor: "${nord.nord4}"
            keyColor: "${nord.nord9}"
            numKeyColor: "${nord.nord9}"
          crumbs:
            fgColor: "${nord.nord4}"
            bgColor: "${nord.nord1}"
            activeColor: "${nord.nord8}"
          status:
            newColor: "${nord.nord8}"
            modifyColor: "${nord.nord15}"
            addColor: "${nord.nord14}"
            errorColor: "${nord.nord11}"
            highlightColor: "${nord.nord12}"
            killColor: "${nord.nord3}"
            completedColor: "${nord.nord3}"
          title:
            fgColor: "${nord.nord4}"
            bgColor: "${nord.nord1}"
            highlightColor: "${nord.nord12}"
            counterColor: "${nord.nord15}"
            filterColor: "${nord.nord9}"
        views:
          charts:
            bgColor: default
            defaultDialColors:
              - "${nord.nord15}"
              - "${nord.nord11}"
            defaultChartColors:
              - "${nord.nord15}"
              - "${nord.nord11}"
          table:
            fgColor: "${nord.nord4}"
            bgColor: default
            cursorFgColor: "${nord.nord0}"
            cursorBgColor: "${nord.nord8}"
            markColor: "${nord.nord12}"
            header:
              fgColor: "${nord.nord4}"
              bgColor: default
              sorterColor: "${nord.nord8}"
          xray:
            fgColor: "${nord.nord4}"
            bgColor: default
            cursorColor: "${nord.nord1}"
            graphicColor: "${nord.nord15}"
            showIcons: false
          yaml:
            keyColor: "${nord.nord9}"
            colonColor: "${nord.nord15}"
            valueColor: "${nord.nord4}"
          logs:
            fgColor: "${nord.nord4}"
            bgColor: default
            indicator:
              fgColor: "${nord.nord4}"
              bgColor: "${nord.nord15}"
              toggleOnColor: "${nord.nord15}"
              toggleOffColor: "${nord.nord9}"
          help:
            fgColor: "${nord.nord4}"
            bgColor: "${nord.nord0}"
            indicator:
              fgColor: "${nord.nord11}"
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
