# Interactive VM for trying the installer ISO by hand:
#   nix run .#installer-vm            boot the ISO (disk attached)
#   nix run .#installer-vm -- disk    boot the installed disk
#   nix run .#installer-vm -- reset   delete the VM disk and EFI variables
#
# The disk is NVMe, so it shows up as /dev/nvme0n1 like on the laptop, and the
# x16 initrd (which has no virtio drivers) can find it.
# SSH into the VM: ssh -p 2222 root@localhost (live ISO, your key)
# State lives in $INSTALLER_VM_DIR (default: ./.installer-vm).
{
  pkgs,
  iso,
}:
import ../lib/write-nu-app.nix {inherit pkgs; inherit (pkgs) lib;} {
  name = "installer-vm";
  file = ./installer-vm.nu;
  runtimeInputs = [pkgs.qemu_kvm pkgs.coreutils];
  env = {
    ISO_DIR = iso;
    OVMF_CODE = pkgs.OVMF.firmware;
    OVMF_VARS = pkgs.OVMF.variables;
  };
}
