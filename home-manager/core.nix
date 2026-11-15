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
    libargon2
    wl-clipboard

    age
    gnupg
    gpg-tui
    pinentry-curses

    sops

    (python3.withPackages (ps: [
      ps.bech32
    ]))

    dua

    btop
  ];

  home.stateVersion = "24.05";
}
