# Live installer ISO. Boots a minimal NixOS with this flake at
# /etc/nixos-config and an `install-nixos` command that partitions a disk with
# disko and installs one of the flake's hosts onto it.
{
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
    ];
    runtimeEnv = {
      FLAKE = "/etc/nixos-config";
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

  nix.settings.experimental-features = ["nix-command" "flakes"];
  # disko's CLI evaluates the disk layout file against <nixpkgs>.
  nix.nixPath = ["nixpkgs=${inputs.nixpkgs}"];

  # Allow installing remotely: `ssh root@<installer-ip>`.
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJBJcLJ7ZGkut93mp+aAdn3NQVmV3oWIE4xQLcZo3mkl"
  ];
}
