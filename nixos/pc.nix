# Desktop PC: AMD Ryzen 9 9950X3D, Radeon RX 9070 XT. Shared desktop setup is
# in ./desktop.nix. Disk layout: ./disko.nix (installed from the installer ISO).
{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  # Sway's pc-only output and gaming settings (merged into home-manager/sway).
  swayGaming = {
    # VRR. Sway has no fullscreen-only mode: it's on for the desktop too,
    # which can flicker on some monitors. No tearing: with the monitor on the
    # iGPU and games on the RX 9070 XT, tearing capped fullscreen games at ~60
    # FPS in Hyprland (and allow_tearing defaults to off).
    output."*".adaptive_sync = "on";
  };
in {
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
  home-manager.users.${username} = {
    imports = [../home-manager/hyprland ../home-manager/kwin];
    wayland.windowManager.sway.config = swayGaming;
  };

  # The monitor is on the motherboard's USB-C port, which belongs to the CPU's
  # built-in GPU. Render on the RX 9070 XT anyway (as COSMIC does) and use the
  # built-in GPU only to scan out: Hyprland renders on the first device in
  # AQ_DRM_DEVICES, and games pick the compositor's main GPU. The list is
  # colon-separated, so the by-path names (which contain colons) can't be used;
  # these rules add colon-free names, matched by PCI device ID
  # (check with `lspci -nn`: 1002:7550 is the RX 9070 XT, 1002:13c0 the iGPU).
  services.udev.extraRules = ''
    SUBSYSTEM=="drm", KERNEL=="card[0-9]*", ATTRS{vendor}=="0x1002", ATTRS{device}=="0x7550", SYMLINK+="dri/dgpu"
    SUBSYSTEM=="drm", KERNEL=="card[0-9]*", ATTRS{vendor}=="0x1002", ATTRS{device}=="0x13c0", SYMLINK+="dri/igpu"
  '';

  # Sway as a third session. Its config is home-manager/sway (shared with x16's
  # home config); the pc-only settings are swayGaming above.
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  # KWin as a fourth session. NixOS packages it as Plasma: KWin plus Plasma's
  # shell (panel, launcher, lock screen, settings); the optional KDE apps are
  # left out. Shortcuts and keyboard settings: home-manager/kwin.
  services.desktopManager.plasma6.enable = true;
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    aurorae
    plasma-browser-integration
    plasma-workspace-wallpapers
    konsole
    ark
    elisa
    gwenview
    okular
    kate
    ktexteditor
    khelpcenter
    dolphin
    baloo-widgets
    dolphin-plugins
    ffmpegthumbs
    krdp
    plasma-keyboard
    qtvirtualkeyboard
    union
    qrca
    discover
    # Kept: spectacle (screenshots, Super+P), kconfig and qtbase (xdg-utils),
    # qttools (qdbus).
  ];
  # Plasma turns these on by default.
  programs.kde-pim.enable = false;
  services.orca.enable = false;
  # Plasma would make itself the default session.
  services.displayManager.defaultSession = "cosmic";

  environment.sessionVariables = {
    AQ_DRM_DEVICES = "/dev/dri/dgpu:/dev/dri/igpu";
    # The same for sway (wlroots) and KWin: the first device renders.
    WLR_DRM_DEVICES = "/dev/dri/dgpu:/dev/dri/igpu";
    KWIN_DRM_DEVICES = "/dev/dri/dgpu:/dev/dri/igpu";
    # Apps pick their GPU separately from the compositor, and without this they
    # landed on the iGPU. Mesa's OpenGL and Vulkan device selection (and so
    # Proton/DXVK) take the RX 9070 XT as the default GPU by vendor:device ID.
    DRI_PRIME = "1002:7550";
  };
  # Steam's client is an X11 app; ./cosmic/mod.nix turns XWayland off.
  services.desktopManager.cosmic.xwayland.enable = lib.mkForce true;

  # Required; keep it at the release the machine was first installed with.
  # (home-manager's state version comes from home-manager/core.nix.)
  system.stateVersion = "26.11";
}
