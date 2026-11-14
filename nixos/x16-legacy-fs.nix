# Disk layout of the existing x16 install (created by the NixOS installer).
# New installs use ./disko.nix instead (see `nixosConfigurations.x16-disko`).
{
  boot.initrd.luks.devices."luks-27edfe15-68e6-46c1-bfed-59afd4a317d2".device = "/dev/disk/by-uuid/27edfe15-68e6-46c1-bfed-59afd4a317d2";

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/726ada07-abaf-4945-942e-d5ad5aeb7d8c";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/3397-CC85";
    fsType = "vfat";
  };
}
