{
  config,
  lib,
  pkgs,
  modulesPath,
  username,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")

    ./machine.nix

    ./bitcoin/mod.nix
    ./monero/mod.nix

    ./glance
    ./syncthing/mod.nix

    ./qbittorrent
    ./cosmic/mod.nix
    ./mpv
  ];

  hardware = {
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    graphics.enable = true;
    graphics.enable32Bit = true;

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

    bluetooth.enable = true;
  };


  boot.extraModprobeConfig = ''
    blacklist nouveau
    options nouveau modeset=0
  '';
  boot.blacklistedKernelModules = [ "nouveau" "nvidia" "nvidia_drm" "nvidia_modeset" ];
  
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    initrd.availableKernelModules = ["xhci_pci" "nvme" "usbhid" "usb_storage" "sd_mod"];
    initrd.kernelModules = [];
    initrd.luks.devices."luks-27edfe15-68e6-46c1-bfed-59afd4a317d2".device = "/dev/disk/by-uuid/27edfe15-68e6-46c1-bfed-59afd4a317d2";

    supportedFilesystems = ["ntfs"];

    kernelModules = ["kvm-intel" "i2c-dev"];
    kernelPackages = pkgs.linuxPackages_latest;
    kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    extraModulePackages = [];
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/726ada07-abaf-4945-942e-d5ad5aeb7d8c";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/3397-CC85";
    fsType = "vfat";
  };

  swapDevices = [];

  networking = {
    hostName = "x16";
    useDHCP = lib.mkDefault true;

    firewall.enable = true;
    firewall.trustedInterfaces = [ "virbr0" ];

    nftables.enable = true;
  };

  security.polkit.enable = true;

  services.asusd.enable = true;

  services.memos.enable = true;

  services.tor = {
    # enable = true;
    # settings = {
    #   HiddenServiceDir = "/var/lib/tor/test-service/";
        #   HiddenServicePort = "3000 127.0.0.1:3000";
    # };
    
    relay.onionServices.test = {
      path = "/var/lib/tor/test-service/";
      map = [3000];
    };
  };

  services = {
    mullvad-vpn = {
      enable = true;
      package = pkgs.mullvad-vpn;
    };
    udev.packages = with pkgs; [
      qmk-udev-rules
    ];
    udev.extraRules = ''
      KERNEL=="hidraw*", ATTRS{idVendor}=="d13e", ATTRS{idProduct}=="cc10", GROUP="plugdev", MODE="0666", SYMLINK+="coldcard"
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
    blueman.enable = true;
  };

  services.navidrome = {
    enable = true;
    settings = {
      MusicFolder = "/home/${username}/sync/music";
    };
  };
  systemd.services.navidrome.serviceConfig.ProtectHome = lib.mkForce false;

  systemd.user.services."stalker" = {
    after = ["network.target"];
    wantedBy = ["default.target"];
    serviceConfig = {
      ExecStart = "/home/${username}/.cargo/bin/stalker-bin";
      LimitNOFILE = 65536;
    };
    environment = {
      RUST_LOG = "info,sqlx=error";
      DATA_DIR = "/home/${username}/stalker-data";
    };
  };

  services.xserver = {
    xkb.layout = "us";
    xkb.variant = "";
    xkb.options = "grp:win_space_toggle";
    videoDrivers = ["intel"];
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
    asusctl

    firefox
    mullvad-vpn
    tor-browser

    mullvad-browser

    # logseq

    electrum

    qmk

    restic
    rclone
  ];

  fonts.packages = with pkgs; [
    fira-code
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Logseq still uses this.
  # TODO: Revisit
  nixpkgs.config.permittedInsecurePackages = [
    "electron-39.8.10"
  ];

  home-manager = {
    extraSpecialArgs = {
      inherit username;
    };

    users."${username}" = import ../home-manager/x16.nix;
  };
}
