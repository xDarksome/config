# Disk layout for new installs: GPT with an EFI system partition and a
# LUKS-encrypted ext4 root.
#
# Used in two ways:
# - as a NixOS module (imported by hosts), where it generates `fileSystems`
#   and `boot.initrd.luks`. These refer to partitions by label, so `device`
#   only matters at format time.
# - by the disko CLI in the installer, which passes the target disk:
#   disko --mode destroy,format,mount --argstr device /dev/nvme0n1 ./disko.nix
{device ? "/dev/nvme0n1", ...}: {
  disko.devices.disk.main = {
    type = "disk";
    inherit device;
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = ["umask=0077"];
          };
        };
        luks = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            settings.allowDiscards = true;
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
