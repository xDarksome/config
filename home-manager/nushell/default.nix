{
  pkgs,
  config,
  username,
  ...
}: {
  home.packages = with pkgs; [
    nushell
    nushellPlugins.formats
  ];

  home.file.".config/nushell".source = config.lib.file.mkOutOfStoreSymlink "/home/${username}/nixos-config/home-manager/nushell";
}
