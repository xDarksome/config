{
  lib,
  pkgs,
  username,
  inputs,
  ...
}: {
  services = {
    displayManager.cosmic-greeter.enable = true;
    desktopManager.cosmic = {
      enable = true;
      xwayland.enable = false;
    };
  };

  environment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = "true";

  system.activationScripts.symlinks.text = lib.mkAfter ''
    install -d -o ${username} -g users /home/${username}/.config
    rm -rf /home/${username}/.config/cosmic
    ln -s /home/${username}/nixos-config/nixos/cosmic/config /home/${username}/.config/cosmic
  '';
}
