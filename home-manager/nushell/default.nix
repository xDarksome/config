{
  pkgs,
  config,
  username,
  ...
}: {
  home.packages = with pkgs; [
    nushell
    nushellPlugins.formats

    (writeShellApplication {
      name = "derive-password";

      runtimeInputs = [
        libargon2
        wl-clipboard-rs
      ];

      text = ''nu ${./derive-password.nu} "$@"'';
    })
  ];

  home.file.".config/nushell".source = config.lib.file.mkOutOfStoreSymlink "/home/${username}/nixos-config/home-manager/nushell";
}
