# Automated VM test of the installer ISO (nix flake check, or
# nix build .#checks.x86_64-linux.installer). The test script is ./installer.py.
#
# Boots the ISO under UEFI with an empty NVMe disk and no network, checks the
# live system, then runs install-nixos through its prompts (offline, --no-vpn)
# and boots the installed disk, unlocking LUKS. It installs the small
# `installer-test` host instead of x16, which is too big to install under
# emulation; the Mullvad login flow needs a real account, so try that with
# `nix run .#installer-vm`.
{
  pkgs,
  installer,
  username,
}: let
  # The real ISO, bundling only the test host, plus the test driver's backdoor
  # so the test can run commands.
  iso =
    (installer.extendModules {
      modules = [
        "${pkgs.path}/nixos/modules/testing/test-instrumentation.nix"
        {installer.hosts = ["installer-test"];}
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
    "@username@" = username;
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
