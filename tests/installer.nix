# Automated smoke test of the installer ISO (nix flake check, or
# nix build .#checks.x86_64-linux.installer). Boots the ISO under UEFI with an
# empty NVMe disk and no network, and checks that the installer is set up
# correctly and refuses to install without Mullvad. It does not run an install:
# that needs the network and a Mullvad account, use `nix run .#installer-vm`.
# The test script is ./installer.py.
{
  pkgs,
  installer,
}: let
  # The real ISO plus the test driver's backdoor, so the test can run commands.
  iso =
    (installer.extendModules {
      modules = [
        "${pkgs.path}/nixos/modules/testing/test-instrumentation.nix"
      ];
    })
    .config
    .system
    .build
    .isoImage;

  substitutions = {
    "@iso@" = "${iso}";
    "@qemu@" = "${pkgs.qemu_test}/bin/qemu-system-x86_64";
    "@qemuImg@" = "${pkgs.qemu_test}/bin/qemu-img";
    "@ovmfCode@" = "${pkgs.OVMF.firmware}";
    "@ovmfVars@" = "${pkgs.OVMF.variables}";
  };
in
  pkgs.testers.runNixOSTest {
    name = "installer-iso";
    nodes = {};
    testScript =
      builtins.replaceStrings
      (builtins.attrNames substitutions)
      (builtins.attrValues substitutions)
      (builtins.readFile ./installer.py);
  }
