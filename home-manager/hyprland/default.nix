# Hyprland config (pc only; the session itself is enabled in nixos/pc.nix).
# ~/.config/hypr links to this directory in the checkout, so edits to
# hyprland.lua apply on the next `hyprctl reload`.
{
  config,
  pkgs,
  username,
  ...
}: {
  xdg.configFile."hypr".source = config.lib.file.mkOutOfStoreSymlink "/home/${username}/nixos-config/home-manager/hyprland";

  home.packages = with pkgs; [
    fuzzel # launcher (Super+C)
    grim # screenshot (Super+P), with slurp to pick a region
    slurp
  ];
}
