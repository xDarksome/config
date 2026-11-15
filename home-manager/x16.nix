{
  pkgs,
 ...
}: {
  imports = [
    ./core.nix

    ./sway
    ./wezterm
  ];

  home.packages = with pkgs; [
    wl-clipboard
  ];
}
