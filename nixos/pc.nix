# Desktop PC: AMD Ryzen 9 9950X3D, Radeon RX 9070 XT. Shared desktop setup is
# in ./desktop.nix. Disk layout: ./disko.nix (installed from the installer ISO).
{
  config,
  lib,
  username,
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

  programs.steam.enable = true;

  # Per game, set Steam's launch options to `gamemoderun %command%`. While a
  # game runs, GameMode switches the CPU to its performance governor, raises
  # the game's priority, and pins it to the CCD with the 3D V-Cache (found from
  # the L3 sizes; pin_cores is on by default).
  programs.gamemode = {
    enable = true;
    settings.general.renice = 10;
  };

  # Hyprland as a second session next to COSMIC (pick it in the login screen).
  # Its config and shortcuts are in home-manager/hyprland.
  programs.hyprland.enable = true;
  # Super+L; the NixOS module also sets up its PAM service.
  programs.hyprlock.enable = true;
  home-manager.users.${username}.imports = [../home-manager/hyprland];
  # Steam's client is an X11 app; ./cosmic/mod.nix turns XWayland off.
  services.desktopManager.cosmic.xwayland.enable = lib.mkForce true;

  # Required; keep it at the release the machine was first installed with.
  # (home-manager's state version comes from home-manager/core.nix.)
  system.stateVersion = "26.11";
}
