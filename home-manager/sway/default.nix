# Sway. The shortcuts are ported from the COSMIC ones in
# nixos/cosmic/config/com.system76.CosmicSettings.Shortcuts/v1/custom, the same
# as Hyprland's (home-manager/hyprland/hyprland.lua); keyboard settings from
# .../com.system76.CosmicComp/v1. pc's gaming and GPU settings are in
# nixos/pc.nix.
{
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    fuzzel # launcher (Super+C)
    grim # screenshot (Super+P), with slurp to pick a region
    slurp
  ];

  wayland.windowManager.sway = let
    mod = "Mod4";
    # Focus and move on h/t/d/s (left/down/up/right); with Ctrl, move the
    # window.
    directions = {
      h = "left";
      t = "down";
      d = "up";
      s = "right";
    };
    # Workspaces 1-9 on i e a y o u x j k; with Ctrl, move the window there.
    workspaceKeys = ["i" "e" "a" "y" "o" "u" "x" "j" "k"];

    directionBindings = builtins.foldl' (acc: key:
      acc
      // {
        "${mod}+${key}" = "focus ${directions.${key}}";
        "${mod}+Ctrl+${key}" = "move ${directions.${key}}";
      }) {} (builtins.attrNames directions);

    workspaceBindings = builtins.listToAttrs (builtins.concatLists (pkgs.lib.imap1 (n: key: [
        {
          name = "${mod}+${key}";
          value = "workspace number ${toString n}";
        }
        {
          name = "${mod}+Ctrl+${key}";
          value = "move container to workspace number ${toString n}; workspace number ${toString n}";
        }
      ])
      workspaceKeys));
  in {
    enable = true;
    config = {
      modifier = mod;

      left = "h";
      down = "t";
      up = "d";
      right = "s";

      # output."*" = {
      #   bg = "~/sync/wallpapers/cyborg-girl-white.jpg fit";
      # };

      # Logitech G502 ID doesn't work for some reason, so it's hacked by setting wildcard and then
      # ovewriting for everything else.
      input = {
        "*" = {
          # No mouse acceleration.
          accel_profile = "flat";
          pointer_accel = "0.0";
        };
        "1133:16495:Logitech_MX_Ergo" = {
          accel_profile = "adaptive";
        };
        "type:keyboard" = {
          "repeat_delay" = "350";
          "repeat_rate" = "25";
          "xkb_model" = "pc104";
          "xkb_layout" = "us,ru";
          # Super+Space switches the layout.
          "xkb_options" = "grp:win_space_toggle";
        };
        "type:touch" = {
          "events" = "disabled";
        };
        "type:touchpad" = {
          "events" = "enabled";
        };
      };

      keybindings =
        directionBindings
        // workspaceBindings
        // {
          "${mod}+n" = "exec cosmic-term";
          "${mod}+c" = "exec fuzzel";
          "${mod}+l" = "exec swaylock -f -c 000000";
          "${mod}+p" = ''exec grim -g "$(slurp)" - | wl-copy'';

          "${mod}+b" = "kill";
          "${mod}+f" = "fullscreen toggle";
          # COSMIC's "Terminate": end the session.
          "${mod}+Ctrl+Escape" = "exit";
        };

      startup = [
        {
          command = "${pkgs.nushell}/bin/nu ${./highest-refresh.nu}";
          always = true;
        }
      ];

      bars = [
        {
          mode = "hide";
          hiddenState = "hide";
          statusCommand = "while date +'%Y-%m-%d %I:%M:%S %p'; do sleep 1; done";
        }
      ];
    };

    extraConfigEarly = ''
      exec swww-daemon
    '';

    extraConfig = ''
      exec swww-daemon
      exec swww img sync/wallpapers/cyborg-girl-white.jpg

      smart_borders on
      default_border pixel 1
      default_floating_border pixel 1
      font pango:monospace 10
      titlebar_padding 1
      titlebar_border_thickness 1
    '';
  };
}
