# Write the installer ISO to a USB stick: nix run .#installer-usb -- /dev/sdX
#
# The ISO is a hybrid image: it carries its own partition table and
# filesystems, laid out the way the NixOS boot setup expects. So the stick is
# partitioned and formatted by writing the image to the whole device; before
# that, any old partitions are unmounted and their signatures wiped, and
# afterwards the stick is read back and compared with the ISO.
# Environment (set by the wrapper): ISO_DIR.

usage() {
  echo "usage: installer-usb [--force] <device>" >&2
  echo "  e.g. installer-usb /dev/sdb" >&2
  echo "  --force  allow a disk that isn't USB or removable (or a loop device)" >&2
  echo >&2
  lsblk -d -o NAME,SIZE,TRAN,RM,MODEL,TYPE >&2
  exit 1
}

force=0
if [[ ${1:-} == --force ]]; then
  force=1
  shift
fi
[[ $# -eq 1 ]] || usage
dev=$1

if [[ $EUID -ne 0 ]]; then
  echo "Writing to $dev needs root, re-running with sudo"
  exec sudo "$0" "$@"
fi

isos=("$ISO_DIR"/iso/*.iso)
iso=${isos[0]}

[[ -b $dev ]] || { echo "$dev is not a block device" >&2; usage; }
dev=$(readlink -f "$dev")
type=$(lsblk -dno TYPE "$dev")
# --force also allows loop devices (writing to an image file).
if [[ $type != disk && ! ($type == loop && $force -eq 1) ]]; then
  echo "$dev is a $type, not a whole disk (give e.g. /dev/sdb, not /dev/sdb1)" >&2
  exit 1
fi

# Never the disk the running system is on.
for mnt in / /nix /boot; do
  src=$(findmnt -no SOURCE "$mnt" 2>/dev/null || true)
  [[ -n $src ]] || continue
  for parent in $(lsblk -nspo NAME "$src" 2>/dev/null); do
    if [[ $parent == "$dev" ]]; then
      echo "$dev holds $mnt of the running system, refusing" >&2
      exit 1
    fi
  done
done

tran=$(lsblk -dno TRAN "$dev" | xargs)
removable=$(lsblk -dno RM "$dev" | xargs)
if [[ $tran != usb && $removable != 1 && $force -eq 0 ]]; then
  echo "$dev is not a USB or removable disk (transport: ${tran:-none}); pass --force if you're sure" >&2
  exit 1
fi

iso_size=$(stat -c %s "$iso")
dev_size=$(blockdev --getsize64 "$dev")
if ((dev_size < iso_size)); then
  echo "$dev is too small: $((dev_size / 1024 / 1024)) MiB, the ISO is $((iso_size / 1024 / 1024)) MiB" >&2
  exit 1
fi

echo "ISO:    $iso ($((iso_size / 1024 / 1024)) MiB)"
echo "Target: everything on this device will be ERASED:"
lsblk -o NAME,SIZE,TRAN,MODEL,FSTYPE,LABEL,MOUNTPOINTS "$dev"
name=${dev#/dev/}
read -rp "Type '$name' to continue: " answer
[[ $answer == "$name" ]] || { echo "aborted" >&2; exit 1; }

echo "==> Unmounting and wiping $dev"
for part in $(lsblk -lnpo NAME "$dev" | tail -n +2); do
  if findmnt -rno TARGET -S "$part" >/dev/null 2>&1; then
    umount "$part"
  fi
  wipefs --all --quiet "$part" || true
done
wipefs --all --quiet "$dev"

echo "==> Writing the ISO"
dd if="$iso" of="$dev" bs=4M conv=fsync oflag=direct status=progress
sync
# Let the kernel see the image's partitions (some devices can't, harmless).
blockdev --rereadpt "$dev" 2>/dev/null || true

echo "==> Verifying"
if ! cmp -n "$iso_size" "$iso" "$dev"; then
  echo "verification failed: $dev differs from the ISO" >&2
  exit 1
fi

echo "==> Done. $dev is ready to boot:"
lsblk -o NAME,SIZE,FSTYPE,LABEL "$dev"
