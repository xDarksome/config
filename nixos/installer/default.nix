# Live installer ISO. Boots a minimal NixOS into a root Nushell with this flake
# at /etc/nixos-config and an `install-nixos` command that partitions a disk
# and installs one of the flake's hosts onto it. Everything the install needs (each
# host's system closure and disk script) is on the ISO, so it works offline.
{
  config,
  pkgs,
  lib,
  inputs,
  username,
  ...
}: let
  cfg = config.installer;
  hostConfig = name: inputs.self.nixosConfigurations.${name}.config;

  # <host>/system: the system closure, <host>/disko: its disk script
  # (destroy, format, mount; targets /run/install-target, see nixos/disko.nix).
  hostsDir = pkgs.linkFarm "installer-hosts" (lib.concatMap (name: [
      {
        name = "${name}/system";
        path = (hostConfig name).system.build.toplevel;
      }
      {
        name = "${name}/disko";
        path = (hostConfig name).system.build.destroyFormatMount;
      }
    ])
    cfg.hosts);

  # Commands install-nixos runs. With no wrapper, they come from the system.
  installTools = with pkgs; [
    git
    nixos-install-tools
    util-linux
    coreutils
    iproute2
    config.services.mullvad-vpn.package
    config.networking.networkmanager.package
  ];

  # install-nixos as a Nushell module that every interactive shell auto-loads
  # (from share/nushell/vendor/autoload of installed packages), with its
  # settings next to it. Parse-checked at build time.
  install-nixos =
    pkgs.runCommand "install-nixos" {
      nativeBuildInputs = [pkgs.nushell];
      settings = builtins.toJSON {
        flake = "/etc/nixos-config";
        # Commit the ISO was built from (dirty if built with uncommitted changes).
        flake_rev = inputs.self.rev or inputs.self.dirtyRev or "unknown";
        hosts_dir = hostsDir;
        inherit username;
        repo_url = "https://github.com/xDarksome/config";
      };
      passAsFile = ["settings"];
    } ''
      module=$out/share/nushell/install-nixos
      install -Dm644 ${./install-nixos.nu} $module/install-nixos.nu
      install -Dm644 $settingsPath $module/settings.json
      nu --no-config-file --commands "nu-check --debug --as-module '$module/install-nixos.nu'" >/dev/null

      mkdir -p $out/share/nushell/vendor/autoload
      echo "use $module/install-nixos.nu" > $out/share/nushell/vendor/autoload/install-nixos.nu
    '';
in {
  options.installer.hosts = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    description = "nixosConfigurations to bundle on the ISO and offer in install-nixos.";
    # Every host with a disko layout, except the installer and its test host.
    default =
      builtins.filter (
        name: !lib.hasPrefix "installer" name && (hostConfig name) ? disko
      )
      (builtins.attrNames inputs.self.nixosConfigurations);
  };

  config = {
    image.baseName = lib.mkForce "nixos-installer";
    # The bundled systems make the image large; zstd at a moderate level keeps
    # the build fast.
    isoImage.squashfsCompression = "zstd -Xcompression-level 6";

    # The flake source this ISO was built from.
    environment.etc."nixos-config".source = inputs.self;

    environment.systemPackages = [install-nixos pkgs.nushell] ++ installTools;
    # Link share/nushell into the system profile, where Nushell's vendor
    # autoload finds install-nixos (via XDG_DATA_DIRS).
    environment.pathsToLink = ["/share/nushell"];

    # Log in as root on tty1, into Nushell, where install-nixos is a command.
    services.getty.autologinUser = lib.mkForce "root";
    users.defaultUserShell = pkgs.nushell;
    environment.shells = [pkgs.nushell];

    # Route network access through Mullvad. Log in on the live system (see
    # install-nixos.sh); the account number is never baked into the ISO.
    services.mullvad-vpn.enable = true; # CLI-only package, no GUI
    services.resolved.enable = true;
    # Don't contact NTP servers from the real IP before the tunnel is up.
    services.timesyncd.enable = false;

    nix.settings.experimental-features = ["nix-command" "flakes"];

    # Allow installing remotely: `ssh root@<installer-ip>`.
    users.users.root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJBJcLJ7ZGkut93mp+aAdn3NQVmV3oWIE4xQLcZo3mkl"
    ];
  };
}
