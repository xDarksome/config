# Small host for the installer's end-to-end VM test (tests/installer.nix):
# the real disk layout (nixos/disko.nix) and bootloader setup, without the
# x16 closure, which is too big to install under emulation in a test.
{
  lib,
  modulesPath,
  username,
  ...
}: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    # Lets the test driver run commands in the installed system.
    (modulesPath + "/testing/test-instrumentation.nix")
    ../nixos/disko.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.availableKernelModules = ["nvme"];
  # Put the console (and the LUKS passphrase prompt) on serial, last console
  # wins, so the test can answer it.
  boot.kernelParams = lib.mkAfter ["console=ttyS0"];

  networking.hostName = "installer-test";
  users.users.${username}.isNormalUser = true;

  system.stateVersion = "25.11";
}
