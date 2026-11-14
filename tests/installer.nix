# Automated smoke test of the installer ISO (nix flake check, or
# nix build .#checks.x86_64-linux.installer). Boots the ISO under UEFI with an
# empty NVMe disk and no network, and checks that the installer is set up
# correctly and refuses to install without Mullvad. It does not run an install:
# that needs the network and a Mullvad account, use `nix run .#installer-vm`.
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

  qemu = "${pkgs.qemu_test}/bin/qemu-system-x86_64";
in
  pkgs.testers.runNixOSTest {
    name = "installer-iso";
    nodes = {};
    testScript = ''
      import glob
      import os
      import subprocess

      iso_file = glob.glob("${iso}/iso/*.iso")[0]

      disk = os.path.join(os.environ.get("TMPDIR", "/tmp"), "disk.qcow2")
      vars = os.path.join(os.environ.get("TMPDIR", "/tmp"), "OVMF_VARS.fd")
      subprocess.run(["${pkgs.qemu_test}/bin/qemu-img", "create", "-q", "-f", "qcow2", disk, "8G"], check=True)
      subprocess.run(["install", "-m", "644", "${pkgs.OVMF.variables}", vars], check=True)

      machine = create_machine(" ".join([
          "${qemu} -machine q35 -m 2048",
          "-drive if=pflash,format=raw,unit=0,readonly=on,file=${pkgs.OVMF.firmware}",
          f"-drive if=pflash,format=raw,unit=1,file={vars}",
          f"-drive if=none,id=disk,format=qcow2,file={disk}",
          "-device nvme,drive=disk,serial=test",
          f"-drive media=cdrom,readonly=on,file={iso_file}",
          "-boot order=d",
      ]))
      machine.start()
      machine.wait_for_unit("multi-user.target")

      with subtest("booted under UEFI"):
          machine.succeed("test -d /sys/firmware/efi")

      with subtest("flake is bundled"):
          machine.succeed("test -f /etc/nixos-config/flake.nix")
          machine.succeed("test -f /etc/nixos-config/flake.lock")
          machine.succeed("test -f /etc/nixos-config/nixos/disko.nix")

      with subtest("tools are installed"):
          for tool in ["install-nixos", "disko", "git", "mullvad", "nixos-install"]:
              machine.succeed(f"command -v {tool}")

      with subtest("Mullvad daemon runs, time sync is off"):
          machine.wait_for_unit("mullvad-daemon.service")
          machine.wait_until_succeeds("mullvad status")
          machine.fail("systemctl is-active systemd-timesyncd.service")
          machine.succeed("systemctl is-active systemd-resolved.service")

      with subtest("install-nixos shows usage without arguments"):
          out = machine.fail("install-nixos 2>&1")
          assert "usage: install-nixos" in out, out
          assert "nvme0n1" in out, out

      with subtest("install-nixos refuses without Mullvad and leaves the disk alone"):
          out = machine.fail("install-nixos x16-disko /dev/nvme0n1 2>&1")
          assert "Mullvad is not connected" in out, out
          machine.fail("test -e /dev/nvme0n1p1")

      machine.shutdown()
    '';
  }
