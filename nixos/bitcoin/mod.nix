{
  lib,
  pkgs,
  username,
  inputs,
  ...
}: let
  nix-bitcoin = inputs.nix-bitcoin;
in {
  imports = [nix-bitcoin.nixosModules.default];

  # nix-bitcoin is archived (v0.0.139 is its last release) and still sets
  # services.i2pd.proto.sam, which NixOS 26.11 removed when i2pd moved to
  # `settings`. It does so only with netns isolation, which is off here, but
  # setting an option that doesn't exist fails evaluation even then. Declare
  # the old option as an unused stand-in so it evaluates.
  options.services.i2pd.proto = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = {};
    internal = true;
    description = "Stand-in for an option nix-bitcoin still sets; unused.";
  };

  config = {
    # Automatically generate all secrets required by services.
    # The secrets are stored in /etc/nix-bitcoin-secrets
    nix-bitcoin.generateSecrets = true;

    services.bitcoind.enable = true;
    services.electrs.enable = true;

    # When using nix-bitcoin as part of a larger NixOS configuration, set the following to enable
    # interactive access to nix-bitcoin features (like bitcoin-cli) for your system's main user
    nix-bitcoin.operator = {
      enable = true;
      name = username;
    };

    # If you use a custom nixpkgs version for evaluating your system
    # (instead of `nix-bitcoin.inputs.nixpkgs` like in this example),
    # consider setting `useVersionLockedPkgs = true` to use the exact pkgs
    # versions for nix-bitcoin services that are tested by nix-bitcoin.
    # The downsides are increased evaluation times and increased system
    # closure size.
    nix-bitcoin.useVersionLockedPkgs = true;
  };
}
