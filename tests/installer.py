# Test script for installer.nix. The "@name@" strings are values that
# installer.nix substitutes in.
import glob
import os
import subprocess

ISO_DIR = "@iso@"
QEMU = "@qemu@"
QEMU_IMG = "@qemuImg@"
OVMF_CODE = "@ovmfCode@"
OVMF_VARS = "@ovmfVars@"
USERNAME = "@username@"

LUKS_PASSPHRASE = "test-luks-passphrase"
USER_PASSWORD = "test-user-password"

tmp = os.environ.get("TMPDIR", "/tmp")
iso_file = glob.glob(f"{ISO_DIR}/iso/*.iso")[0]
disk = os.path.join(tmp, "disk.qcow2")
efi_vars = os.path.join(tmp, "OVMF_VARS.fd")
subprocess.run([QEMU_IMG, "create", "-q", "-f", "qcow2", disk, "8G"], check=True)
subprocess.run(["install", "-m", "644", OVMF_VARS, efi_vars], check=True)


def start_command(with_iso):
    # The same UEFI firmware, EFI variables and disk for both boots, so the
    # installed system boots from the entry its bootloader registered.
    flags = [
        f"{QEMU} -machine q35 -m 2048",
        f"-drive if=pflash,format=raw,unit=0,readonly=on,file={OVMF_CODE}",
        f"-drive if=pflash,format=raw,unit=1,file={efi_vars}",
        f"-drive if=none,id=disk,format=qcow2,file={disk}",
        "-device nvme,drive=disk,serial=test",
    ]
    if with_iso:
        flags += [f"-drive media=cdrom,readonly=on,file={iso_file}", "-boot order=d"]
    return " ".join(flags)


machine = create_machine(start_command(with_iso=True), name="installer")
machine.start()
machine.wait_for_unit("multi-user.target")

with subtest("booted under UEFI"):
    machine.succeed("test -d /sys/firmware/efi")

with subtest("flake is bundled"):
    machine.succeed("test -f /etc/nixos-config/flake.nix")
    machine.succeed("test -f /etc/nixos-config/flake.lock")
    machine.succeed("test -f /etc/nixos-config/nixos/disko.nix")

with subtest("tools are installed"):
    for tool in ["install-nixos", "git", "mullvad", "nixos-install", "nmtui"]:
        machine.succeed(f"command -v {tool}")

with subtest("Mullvad daemon runs, time sync is off"):
    machine.wait_for_unit("mullvad-daemon.service")
    machine.wait_until_succeeds("mullvad status")
    machine.fail("systemctl is-active systemd-timesyncd.service")
    machine.succeed("systemctl is-active systemd-resolved.service")

with subtest("install-nixos shows usage when it can't prompt"):
    # Commands run without a terminal, so missing arguments can't be asked for.
    out = machine.fail("install-nixos 2>&1 </dev/null")
    assert "usage: install-nixos" in out, out
    assert "hosts: installer-test" in out, out
    assert "nvme0n1" in out, out

with subtest("install-nixos rejects hosts that aren't bundled"):
    out = machine.fail("install-nixos x16 /dev/nvme0n1 2>&1 </dev/null")
    assert "unknown host 'x16'" in out, out

with subtest("install-nixos refuses without Mullvad and leaves the disk alone"):
    # Without a terminal it can't run the Mullvad login flow, so it stops.
    out = machine.fail("install-nixos installer-test /dev/nvme0n1 2>&1 </dev/null")
    assert "Mullvad is not connected" in out, out
    machine.fail("test -e /dev/nvme0n1p1")

with subtest("install offline through the prompts on tty1"):
    # tty1 is logged in as the `nixos` user on the live ISO.
    machine.wait_until_tty_matches("1", r"nixos@nixos")
    machine.send_chars("sudo -i\n")
    machine.wait_until_tty_matches("1", r"root@nixos")
    machine.send_chars("install-nixos --no-vpn installer-test /dev/nvme0n1\n")

    machine.wait_until_tty_matches("1", r"Type 'yes' to continue")
    machine.send_chars("yes\n")
    machine.wait_until_tty_matches("1", r"Enter password for .*: ")
    machine.send_chars(LUKS_PASSPHRASE + "\n")
    machine.wait_until_tty_matches("1", r"again to be safe")
    machine.send_chars(LUKS_PASSPHRASE + "\n")

    machine.wait_until_tty_matches("1", r"New password", timeout=3600)
    machine.send_chars(USER_PASSWORD + "\n")
    machine.wait_until_tty_matches("1", r"Retype new password")
    machine.send_chars(USER_PASSWORD + "\n")
    machine.wait_until_tty_matches("1", r"==> Done")

with subtest("installed system has the config and no Mullvad login"):
    home = f"/mnt/home/{USERNAME}"
    machine.succeed(f"test -f {home}/nixos-config/flake.nix")
    machine.succeed(f"git -C {home}/nixos-config remote get-url origin | grep -q github.com")
    machine.succeed(f"test \"$(stat -c %U {home}/nixos-config)\" = {USERNAME}")
    # --no-vpn: nothing to copy.
    machine.fail("test -e /mnt/etc/mullvad-vpn")

machine.shutdown()

installed = create_machine(start_command(with_iso=False), name="installed")
installed.start()

with subtest("installed system unlocks LUKS and boots"):
    installed.wait_for_console_text("Passphrase for")
    installed.send_console(LUKS_PASSPHRASE + "\n")
    installed.wait_for_unit("multi-user.target")
    installed.succeed("test \"$(hostname)\" = installer-test")
    installed.succeed("findmnt -no SOURCE / | grep -q cryptroot")
    installed.succeed("findmnt -no FSTYPE /boot | grep -q vfat")
    installed.succeed(f"id {USERNAME}")
    installed.succeed("bootctl is-installed")

installed.shutdown()
