# ASUS laptop (Intel CPU, NVIDIA dGPU kept powered off). Shared desktop setup
# is in ./desktop.nix.
{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./desktop.nix

    ./bitcoin/mod.nix
    ./monero/mod.nix

    ./glance
    ./syncthing/mod.nix

    ./qbittorrent
  ];

  hardware = {
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    # nvidia = {
    #   # Modesetting is required.
    #   modesetting.enable = true;

    #   # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    #   powerManagement.enable = true;
    #   # Fine-grained power management. Turns off GPU when not in use.
    #   # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    #   # powerManagement.finegrained = true;

    #   # Use the NVidia open source kernel module (not to be confused with the
    #   # independent third-party "nouveau" open source driver).
    #   # Support is limited to the Turing and later architectures. Full list of
    #   # supported GPUs is at:
    #   # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
    #   # Only available from driver 515.43.04+
    #   # Currently alpha-quality/buggy, so false is currently the recommended setting.
    #   open = false;

    #   # Enable the Nvidia settings menu,
    #   # accessible via `nvidia-settings`.
    #   nvidiaSettings = true;

    #   # Optionally, you may need to select the appropriate driver version for your specific GPU.
    #   package = config.boot.kernelPackages.nvidiaPackages.beta;
    # };

  };

  boot.extraModprobeConfig = ''
    blacklist nouveau
    options nouveau modeset=0
  '';
  boot.blacklistedKernelModules = [ "nouveau" "nvidia" "nvidia_drm" "nvidia_modeset" ];

  boot.initrd.availableKernelModules = ["xhci_pci" "nvme" "usbhid" "usb_storage" "sd_mod"];
  boot.kernelModules = ["kvm-intel"];

  networking.hostName = "x16";

  services.asusd.enable = true;

  services.udev.extraRules = ''
    KERNELS=="input*", ATTRS{name}=="Asus Keyboard", ENV{LIBINPUT_IGNORE_DEVICE}="1"

    # Remove NVIDIA USB xHCI Host Controller devices, if present
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c0330", ATTR{power/control}="auto", ATTR{remove}="1"
    # Remove NVIDIA USB Type-C UCSI devices, if present
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c8000", ATTR{power/control}="auto", ATTR{remove}="1"
    # Remove NVIDIA Audio devices, if present
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{power/control}="auto", ATTR{remove}="1"
    # Remove NVIDIA VGA/3D controller devices
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x03[0-9]*", ATTR{power/control}="auto", ATTR{remove}="1"
  '';

  services.xserver.videoDrivers = ["intel"];

  environment.systemPackages = with pkgs; [
    asusctl
  ];

  # The state versions are required and should stay at the version you
  # originally installed.
  system.stateVersion = "22.05";
  home-manager.users.darksome.home.stateVersion = "24.05";
}
