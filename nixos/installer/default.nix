# Live installer ISO. Boots a minimal NixOS with this flake at
# /etc/nixos-config and an `install-nixos` command that partitions a disk with
# disko and installs one of the flake's hosts onto it.
{
  config,
  pkgs,
  lib,
  inputs,
  username,
  ...
}: let
  disko = inputs.disko.packages.${pkgs.stdenv.hostPlatform.system}.disko;

  install-nixos = pkgs.writeShellApplication {
    name = "install-nixos";
    runtimeInputs = with pkgs; [
      disko
      git
      nixos-install-tools
      util-linux
      coreutils
      config.services.mullvad-vpn.package
    ];
    runtimeEnv = {
      FLAKE = "/etc/nixos-config";
      # Commit the ISO was built from (dirty if built with uncommitted changes).
      FLAKE_REV = inputs.self.rev or inputs.self.dirtyRev or "unknown";
      USERNAME = username;
      REPO_URL = "https://github.com/xDarksome/config";
    };
    text = builtins.readFile ./install-nixos.sh;
  };
in {
  image.baseName = lib.mkForce "nixos-installer";

  # The flake source this ISO was built from.
  environment.etc."nixos-config".source = inputs.self;

  environment.systemPackages = [
    install-nixos
    disko
    pkgs.git
  ];

  # Route the install through Mullvad. Log in on the live system (see
  # install-nixos.sh); the account number is never baked into the ISO.
  services.mullvad-vpn.enable = true; # CLI-only package, no GUI
  services.resolved.enable = true;
  # Don't contact NTP servers from the real IP before the tunnel is up.
  services.timesyncd.enable = false;

  nix.settings.experimental-features = ["nix-command" "flakes"];
  # disko's CLI evaluates the disk layout file against <nixpkgs>.
  nix.nixPath = ["nixpkgs=${inputs.nixpkgs}"];

  # Allow installing remotely: `ssh root@<installer-ip>`.
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJBJcLJ7ZGkut93mp+aAdn3NQVmV3oWIE4xQLcZo3mkl"
  ];
}
