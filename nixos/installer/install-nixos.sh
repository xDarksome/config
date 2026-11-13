# Usage: install-nixos <host> <disk>
#   host  a nixosConfigurations entry that uses nixos/disko.nix, e.g. x16-disko
#   disk  the whole disk to ERASE and install onto, e.g. /dev/nvme0n1
# Environment (set by the ISO): FLAKE, USERNAME, REPO_URL.

usage() {
  echo "usage: install-nixos <host> <disk>" >&2
  echo "  e.g. install-nixos x16-disko /dev/nvme0n1" >&2
  echo >&2
  lsblk -d -o NAME,SIZE,MODEL,TYPE >&2
  exit 1
}

[[ $# -eq 2 ]] || usage
host=$1
disk=$2

[[ $EUID -eq 0 ]] || { echo "run as root (sudo -i)" >&2; exit 1; }
[[ -b $disk ]] || { echo "$disk is not a block device" >&2; usage; }

if ! nix eval "$FLAKE#nixosConfigurations.$host.config.disko.devices.disk.main.type" >/dev/null; then
  echo "host '$host' does not exist in $FLAKE or does not use disko" >&2
  exit 1
fi

echo "==> Partitioning $disk (this ERASES it; disko will ask to confirm and for the LUKS passphrase)"
disko --mode destroy,format,mount --argstr device "$disk" "$FLAKE/nixos/disko.nix"

echo "==> Installing $host"
nixos-install --flake "$FLAKE#$host" --no-root-passwd

echo "==> Cloning config to /home/$USERNAME/nixos-config"
target=/mnt/home/$USERNAME/nixos-config
if ! git clone "$REPO_URL" "$target"; then
  echo "clone failed, copying the ISO's snapshot instead (no git history)" >&2
  cp -r --no-preserve=mode "$FLAKE/." "$target"
fi
nixos-enter --root /mnt -c "chown -R $USERNAME:users /home/$USERNAME/nixos-config"

echo "==> Set the password for $USERNAME"
until nixos-enter --root /mnt -c "passwd $USERNAME"; do :; done

echo "==> Done. Reboot and remove the installer USB stick."
