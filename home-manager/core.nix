{
  pkgs,
  username,
  ...
}: {
  imports = [
    ./nushell
    ./git
    ./gitui
    ./helix
    ./xplr
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";

  home.packages = with pkgs; [
    zoxide

    file
    unixtools.whereis
    wget
    zip
    unzip
    wl-clipboard

    gnupg
    gpg-tui
    pinentry-curses

    dua

    btop
  ];

  home.stateVersion = "24.05";
}
