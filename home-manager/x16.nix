{
  pkgs,
 ...
}: {
  imports = [
    ./core.nix

    ./sway
    ./wezterm

    ./sway
  ];

  home.packages = with pkgs; [
    wl-clipboard
  ];
}
