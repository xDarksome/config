# nix develop: tools for working on this config, and a Nushell with these
# commands (the scripts are used straight from the checkout, so edits apply on
# the next `nix develop`):
#   installer-usb /dev/sdX   write the installer ISO to a USB stick
#   installer-vm [disk|reset] try the installer ISO in a VM
{pkgs}:
pkgs.mkShell {
  packages = with pkgs; [
    pmbootstrap
    nushell
    # installer-usb
    coreutils
    util-linux
    diffutils
    # installer-vm
    qemu_kvm
  ];

  OVMF_CODE = pkgs.OVMF.firmware;
  OVMF_VARS = pkgs.OVMF.variables;

  # An interactive `nix develop` starts Nushell with the commands loaded;
  # `nix develop -c ...` runs the command as usual.
  shellHook = ''
    if [[ $- == *i* ]]; then
      root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
      exec nu -e "use '$root/nixos/installer/installer-usb.nu'; use '$root/tests/installer-vm.nu'"
    fi
  '';
}
