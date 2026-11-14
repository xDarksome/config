# Test script for installer.nix. The "@name@" strings are store paths that
# installer.nix substitutes in.
import glob
import os
import subprocess

ISO_DIR = "@iso@"
QEMU = "@qemu@"
QEMU_IMG = "@qemuImg@"
OVMF_CODE = "@ovmfCode@"
OVMF_VARS = "@ovmfVars@"

tmp = os.environ.get("TMPDIR", "/tmp")
iso_file = glob.glob(f"{ISO_DIR}/iso/*.iso")[0]
disk = os.path.join(tmp, "disk.qcow2")
efi_vars = os.path.join(tmp, "OVMF_VARS.fd")
subprocess.run([QEMU_IMG, "create", "-q", "-f", "qcow2", disk, "8G"], check=True)
subprocess.run(["install", "-m", "644", OVMF_VARS, efi_vars], check=True)

machine = create_machine(" ".join([
    f"{QEMU} -machine q35 -m 2048",
    f"-drive if=pflash,format=raw,unit=0,readonly=on,file={OVMF_CODE}",
    f"-drive if=pflash,format=raw,unit=1,file={efi_vars}",
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
