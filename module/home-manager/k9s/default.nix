# modules/home-manager/blackmatter/components/k9s/default.nix
#
# K9s Kubernetes TUI — themed skin with abstract color palette.
#
# Colors default to Nord but can be overridden by Stylix (via
# blackmatter's themes/stylix.nix) or any other color source.
# When Stylix is active, base16 scheme colors flow in automatically
# and k9s matches every other themed tool in the ecosystem.
#
# Semantic color mapping (matches skim-tab / blackmatter visual language):
#   cyan    → primary accent, interactive elements, cursor, focus
#   blue    → labels, info, keys, secondary accent
#   green   → healthy, active, additions
#   yellow  → warnings, attention
#   orange  → highlights, marks, suggestions
#   red     → errors, destructive actions
#   purple  → categories, types, counters, indicators
#   teal    → secondary frost accent
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.blackmatter.components.k9s;
  c = cfg.colors;

  # K9s config directory path (macOS uses different location)
  k9sConfigPath = if pkgs.stdenv.isDarwin
    then "Library/Application Support/k9s"
    else ".config/k9s";

  boolStr = b: if b then "true" else "false";
in {
  options.blackmatter.components.k9s = {
    enable = mkEnableOption "K9s Kubernetes TUI with themed skin";

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

    skinName = mkOption {
      type = types.str;
      default = "blackmatter";
      description = "Skin filename (without .yaml extension)";
    };

    # ── Abstract color palette ─────────────────────────────────────
    # Defaults to Nord. Stylix (or any theme system) overrides these.
    colors = {
      # Backgrounds (Polar Night)
      bg        = mkOption { type = types.str; default = "#2e3440"; description = "Darkest background"; };
      bgLight   = mkOption { type = types.str; default = "#3b4252"; description = "Selection / panel background"; };
      bgLighter = mkOption { type = types.str; default = "#434c5e"; description = "Highlight background"; };
      comment   = mkOption { type = types.str; default = "#4c566a"; description = "Comments, borders, muted elements"; };

      # Foregrounds (Snow Storm)
      fgDim     = mkOption { type = types.str; default = "#d8dee9"; description = "Subtle foreground"; };
      fg        = mkOption { type = types.str; default = "#e5e9f0"; description = "Primary foreground"; };
      fgBright  = mkOption { type = types.str; default = "#eceff4"; description = "Bright / emphasized foreground"; };

      # Frost
      teal      = mkOption { type = types.str; default = "#8fbcbb"; description = "Frost teal — secondary accent"; };
      cyan      = mkOption { type = types.str; default = "#88c0d0"; description = "Frost cyan — primary accent"; };
      blue      = mkOption { type = types.str; default = "#81a1c1"; description = "Frost blue — labels, info"; };
      deepBlue  = mkOption { type = types.str; default = "#5e81ac"; description = "Frost deep — subtle accents"; };

      # Aurora
      red       = mkOption { type = types.str; default = "#bf616a"; description = "Error, destructive"; };
      orange    = mkOption { type = types.str; default = "#d08770"; description = "Highlight, mark, attention"; };
      yellow    = mkOption { type = types.str; default = "#ebcb8b"; description = "Warning, caution"; };
      green     = mkOption { type = types.str; default = "#a3be8c"; description = "Healthy, active, added"; };
      purple    = mkOption { type = types.str; default = "#b48ead"; description = "Type, category, indicator"; };
    };
  };

  config = mkIf cfg.enable {
    # ── K9s configuration ────────────────────────────────────────
    home.file."${k9sConfigPath}/config.yaml".text = ''
      k9s:
        refreshRate: ${toString cfg.refreshRate}
        headless: ${boolStr cfg.headless}
        readOnly: ${boolStr cfg.readOnly}
        logoless: ${boolStr cfg.logoless}
        crumbsless: ${boolStr cfg.crumbsless}
        ui:
          enableMouse: true
          headless: ${boolStr cfg.headless}
          logoless: ${boolStr cfg.logoless}
          crumbsless: ${boolStr cfg.crumbsless}
          reactive: false
          noIcons: false
          skin: ${cfg.skinName}
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

    # ── Skin ─────────────────────────────────────────────────────
    # Full k9s 0.50+ spec. Uses "default" for bgColor where possible
    # (inherits terminal background, enables transparency with
    # compositors like Ghostty/Kitty).
    #
    # Color semantics match the blackmatter visual language:
    #   cyan  = interactive / focus / cursor    (skim-tab: Frost items)
    #   blue  = labels / info / keys            (skim-tab: info text)
    #   green = healthy / active / added        (skim-tab: active ns)
    #   yellow = warnings / filter active       (skim-tab: flags)
    #   orange = highlights / marks / suggest   (skim-tab: attention)
    #   red   = errors / destructive            (skim-tab: errors)
    #   purple = types / counters / indicators  (skim-tab: category glyphs)
    home.file."${k9sConfigPath}/skins/${cfg.skinName}.yaml".text = ''
      k9s:
        body:
          fgColor: "${c.fg}"
          bgColor: default
          logoColor: "${c.cyan}"
        prompt:
          fgColor: "${c.fgBright}"
          bgColor: "${c.bg}"
          suggestColor: "${c.orange}"
        info:
          fgColor: "${c.cyan}"
          sectionColor: "${c.blue}"
        dialog:
          fgColor: "${c.fgBright}"
          bgColor: default
          buttonFgColor: "${c.fgBright}"
          buttonBgColor: "${c.blue}"
          buttonFocusFgColor: "${c.bg}"
          buttonFocusBgColor: "${c.cyan}"
          labelFgColor: "${c.orange}"
          fieldFgColor: "${c.fg}"
        frame:
          border:
            fgColor: "${c.comment}"
            focusColor: "${c.cyan}"
          menu:
            fgColor: "${c.fg}"
            keyColor: "${c.cyan}"
            numKeyColor: "${c.cyan}"
          crumbs:
            fgColor: "${c.fgBright}"
            bgColor: "${c.bgLighter}"
            activeColor: "${c.cyan}"
          status:
            newColor: "${c.cyan}"
            modifyColor: "${c.purple}"
            addColor: "${c.green}"
            pendingColor: "${c.yellow}"
            errorColor: "${c.red}"
            highlightColor: "${c.orange}"
            killColor: "${c.red}"
            completedColor: "${c.comment}"
          title:
            fgColor: "${c.fgBright}"
            bgColor: "${c.bgLight}"
            highlightColor: "${c.cyan}"
            counterColor: "${c.purple}"
            filterColor: "${c.yellow}"
        views:
          charts:
            bgColor: default
            defaultDialColors:
              - "${c.cyan}"
              - "${c.red}"
            defaultChartColors:
              - "${c.cyan}"
              - "${c.red}"
          table:
            fgColor: "${c.fg}"
            bgColor: default
            cursorFgColor: "${c.bg}"
            cursorBgColor: "${c.cyan}"
            markColor: "${c.orange}"
            header:
              fgColor: "${c.blue}"
              bgColor: default
              sorterColor: "${c.cyan}"
          xray:
            fgColor: "${c.fg}"
            bgColor: default
            cursorColor: "${c.bgLight}"
            graphicColor: "${c.purple}"
            showIcons: false
          yaml:
            keyColor: "${c.blue}"
            colonColor: "${c.comment}"
            valueColor: "${c.fg}"
          logs:
            fgColor: "${c.fg}"
            bgColor: default
            indicator:
              fgColor: "${c.fgBright}"
              bgColor: "${c.purple}"
              toggleOnColor: "${c.green}"
              toggleOffColor: "${c.comment}"
          help:
            fgColor: "${c.fg}"
            bgColor: "${c.bg}"
            indicator:
              fgColor: "${c.cyan}"
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
