# nix run .#installer-usb -- /dev/sdX: write the installer ISO to a USB stick.
# The script is ./installer-usb.sh.
{
  pkgs,
  iso,
}:
pkgs.writeShellApplication {
  name = "installer-usb";
  runtimeInputs = with pkgs; [coreutils util-linux diffutils findutils];
  runtimeEnv.ISO_DIR = iso;
  text = builtins.readFile ./installer-usb.sh;
}
