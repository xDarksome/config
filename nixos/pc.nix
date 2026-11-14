# Desktop PC: AMD Ryzen 9 9950X3D, Radeon RX 9070 XT. Shared desktop setup is
# in ./desktop.nix. Disk layout: ./disko.nix (installed from the installer ISO).
{
  config,
  lib,
  ...
}: {
  imports = [
    ./desktop.nix
  ];

  hardware = {
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    # Load amdgpu in the initrd for a native-resolution console from early boot
    # and a graphical LUKS prompt.
    amdgpu.initrd.enable = true;
  };

  boot.initrd.availableKernelModules = ["nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod"];
  boot.kernelModules = ["kvm-amd"];

  networking.hostName = "pc";

  # Required; keep it at the release the machine was first installed with.
  # (home-manager's state version comes from home-manager/core.nix.)
  system.stateVersion = "26.11";
}
