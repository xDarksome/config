# Disk layout for new installs: GPT with an EFI system partition and a
# LUKS-encrypted ext4 root.
#
# The installer ISO ships a pre-built disko script per host, so the device is a
# fixed path that install-nixos symlinks to the chosen disk before running it.
# Partitions are referenced by label, so the installed system's fileSystems
# and boot.initrd.luks don't depend on this path.
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/run/install-target";
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
