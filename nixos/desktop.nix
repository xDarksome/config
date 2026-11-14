# Desktop setup shared by x16 and pc: COSMIC, audio, virtualisation, the
# user, and the common services and apps. Hardware and host-specific services
# live in the host files.
{
  pkgs,
  lib,
  modulesPath,
  username,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")

    ./machine.nix

    ./cosmic/mod.nix
    ./mpv
  ];

  hardware = {
    graphics.enable = true;
    graphics.enable32Bit = true;

    bluetooth.enable = true;
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    initrd.kernelModules = [];

    supportedFilesystems = ["ntfs"];

    kernelModules = ["i2c-dev"];
    kernelPackages = pkgs.linuxPackages_latest;
    kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    extraModulePackages = [];
  };

  swapDevices = [];

  networking = {
    useDHCP = lib.mkDefault true;

    firewall.enable = true;
    firewall.trustedInterfaces = [ "virbr0" ];

    nftables.enable = true;
  };

  security.polkit.enable = true;

  services = {
    mullvad-vpn = {
      enable = true;
      package = pkgs.mullvad-vpn;
      # Block traffic from early boot until the daemon has applied its own
      # firewall, so nothing leaves on the real IP before the tunnel is up.
      enableEarlyBootBlocking = true;
    };
    udev.packages = with pkgs; [
      qmk-udev-rules
    ];
    udev.extraRules = ''
      KERNEL=="hidraw*", ATTRS{idVendor}=="d13e", ATTRS{idProduct}=="cc10", GROUP="plugdev", MODE="0666", SYMLINK+="coldcard"
    '';
    blueman.enable = true;
  };

  services.xserver = {
    xkb.layout = "us";
    xkb.variant = "";
    xkb.options = "grp:win_space_toggle";
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  services.dbus.enable = true;

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = ["docker" "dialout" "tty"];
    shell = pkgs.nushell;
  };
  users.users.docker = {
    isNormalUser = true;
    extraGroups = ["docker"];
  };
  users.groups.libvirtd.members = [username];

  virtualisation = {
    docker.enable = true;
    libvirtd.enable = true;
    spiceUSBRedirection.enable = true;
  };

  programs.virt-manager.enable = true;

  environment.systemPackages = with pkgs; [
    firefox
  ];

  fonts.packages = with pkgs; [
    fira-code
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  home-manager = {
    extraSpecialArgs = {
      inherit username;
    };

    users."${username}" = import ../home-manager/x16.nix;
  };
}
