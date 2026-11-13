# Usage: install-nixos [--no-vpn] <host> <disk>
#   host      a nixosConfigurations entry that uses nixos/disko.nix, e.g. x16-disko
#   disk      the whole disk to ERASE and install onto, e.g. /dev/nvme0n1
#   --no-vpn  install without a Mullvad connection (downloads use the real IP)
#
# Before running, connect Mullvad on the live system:
#   mullvad account login          # prompts for the account number
#   mullvad lockdown-mode set on   # block all traffic outside the tunnel
#   mullvad auto-connect set on
#   mullvad connect
#
# Environment (set by the ISO): FLAKE, FLAKE_REV, USERNAME, REPO_URL.

usage() {
  echo "usage: install-nixos [--no-vpn] <host> <disk>" >&2
  echo "  e.g. install-nixos x16-disko /dev/nvme0n1" >&2
  echo >&2
  lsblk -d -o NAME,SIZE,MODEL,TYPE >&2
  exit 1
}

vpn=1
if [[ ${1:-} == --no-vpn ]]; then
  vpn=0
  shift
fi

[[ $# -eq 2 ]] || usage
host=$1
disk=$2

[[ $EUID -eq 0 ]] || { echo "run as root (sudo -i)" >&2; exit 1; }
[[ -b $disk ]] || { echo "$disk is not a block device" >&2; usage; }

if [[ $vpn -eq 1 ]] && [[ $(mullvad status | head -n1) != Connected ]]; then
  echo "Mullvad is not connected. Connect first:" >&2
  echo "  mullvad account login && mullvad lockdown-mode set on && mullvad auto-connect set on && mullvad connect" >&2
  echo "or pass --no-vpn to install over the real IP." >&2
  exit 1
fi

if ! nix eval "$FLAKE#nixosConfigurations.$host.config.disko.devices.disk.main.type" >/dev/null; then
  echo "host '$host' does not exist in $FLAKE or does not use disko" >&2
  exit 1
fi

echo "==> Partitioning $disk (this ERASES it; disko will ask to confirm and for the LUKS passphrase)"
disko --mode destroy,format,mount --argstr device "$disk" "$FLAKE/nixos/disko.nix"

echo "==> Installing $host"
nixos-install --flake "$FLAKE#$host" --no-root-passwd

echo "==> Copying config to /home/$USERNAME/nixos-config (no network)"
# The ISO carries the flake source without .git history. Set up an empty repo
# pointing at the remote; once a VPN is up, `git fetch` + `git reset` attaches
# the history without touching the files.
target=/mnt/home/$USERNAME/nixos-config
cp -r --no-preserve=mode "$FLAKE/." "$target"
git -C "$target" init -q
git -C "$target" remote add origin "$REPO_URL"
nixos-enter --root /mnt -c "chown -R $USERNAME:users /home/$USERNAME/nixos-config"

if [[ $vpn -eq 1 ]]; then
  # Carry the login and settings (lockdown, auto-connect) over, so the new
  # system boots logged in to the same Mullvad device. The daemon recreates the
  # directory if it isn't root-owned and private.
  echo "==> Copying Mullvad login and settings"
  install -d -m 700 -o root -g root /mnt/etc/mullvad-vpn
  cp -p /etc/mullvad-vpn/settings.json /etc/mullvad-vpn/device.json /mnt/etc/mullvad-vpn/
fi

echo "==> Set the password for $USERNAME"
until nixos-enter --root /mnt -c "passwd $USERNAME"; do :; done

echo "==> Done. Reboot and remove the installer USB stick."
if [[ $vpn -eq 1 ]]; then
  echo "    Don't run 'mullvad account logout' here: it would revoke the device"
  echo "    the new system now uses."
fi
echo "    Once the VPN is up, link the config to its git history:"
echo "    cd ~/nixos-config && git fetch origin && git reset $FLAKE_REV"
