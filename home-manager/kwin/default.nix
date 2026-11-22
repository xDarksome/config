# KWin (Plasma) session settings, pc only; the session is enabled in
# nixos/pc.nix. ./apply-config.nu writes the COSMIC shortcuts and keyboard
# settings into Plasma's own config files on every activation.
{
  lib,
  pkgs,
  ...
}: {
  home.activation.kwinConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run ${pkgs.nushell}/bin/nu ${./apply-config.nu} ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6
  '';
}
