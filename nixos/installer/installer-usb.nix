# nix run .#installer-usb -- /dev/sdX: write the installer ISO to a USB stick.
# The script is ./installer-usb.nu.
{
  pkgs,
  iso,
}:
import ../../lib/write-nu-app.nix {inherit pkgs; inherit (pkgs) lib;} {
  name = "installer-usb";
  file = ./installer-usb.nu;
  runtimeInputs = with pkgs; [coreutils util-linux diffutils];
  env.ISO_DIR = iso;
}
