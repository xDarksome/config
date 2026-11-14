# Write the installer ISO to a USB stick: nix run .#installer-usb -- /dev/sdX
#
# The ISO is a hybrid image: it carries its own partition table and
# filesystems, laid out the way the NixOS boot setup expects. So the stick is
# partitioned and formatted by writing the image to the whole device; before
# that, any old partitions are unmounted and their signatures wiped, and
# afterwards the stick is read back and compared with the ISO.
#
# Environment (set at the top of the script): ISO_DIR.

def die [message: string] {
  print -e $message
  exit 1
}

def mib [bytes: int] {
  $bytes // 1024 // 1024
}

def main [
  device: string # the whole disk to write to, e.g. /dev/sdb
  --force # allow a disk that isn't USB or removable (or a loop device)
] {
  if not (is-admin) {
    print $"Writing to ($device) needs root, re-running with sudo"
    let flags = if $force { ["--force"] } else { [] }
    exec sudo $env.CURRENT_FILE ...$flags $device
  }

  let iso = glob $"($env.ISO_DIR)/iso/*.iso" | first

  if (^test -b $device | complete).exit_code != 0 {
    print -e (^lsblk -d -o NAME,SIZE,TRAN,RM,MODEL,TYPE)
    die $"($device) is not a block device"
  }
  let dev = ^readlink -f $device | str trim
  let info = ^lsblk --json -d -b -o NAME,TYPE,TRAN,RM,SIZE $dev | from json | get blockdevices.0

  # --force also allows loop devices (writing to an image file).
  if not ($info.type == "disk" or ($info.type == "loop" and $force)) {
    die $"($dev) is a ($info.type), not a whole disk \(give e.g. /dev/sdb, not /dev/sdb1\)"
  }

  # Never the disk the running system is on.
  for mount in ["/" "/nix" "/boot"] {
    let source = ^findmnt -no SOURCE $mount | complete
    if $source.exit_code != 0 { continue }
    let parents = ^lsblk -nspo NAME ($source.stdout | str trim) | complete
    if ($parents.stdout | lines | str trim | any { $in == $dev }) {
      die $"($dev) holds ($mount) of the running system, refusing"
    }
  }

  if $info.tran? != "usb" and $info.rm != true and not $force {
    die $"($dev) is not a USB or removable disk \(transport: ($info.tran? | default 'none')\); pass --force if you're sure"
  }

  let iso_size = ls $iso | get size.0 | into int
  let dev_size = $info.size | into int
  if $dev_size < $iso_size {
    die $"($dev) is too small: (mib $dev_size) MiB, the ISO is (mib $iso_size) MiB"
  }

  print $"ISO:    ($iso) \((mib $iso_size) MiB\)"
  print "Target: everything on this device will be ERASED:"
  ^lsblk -o NAME,SIZE,TRAN,MODEL,FSTYPE,LABEL,MOUNTPOINTS $dev
  let name = $dev | path basename
  let answer = input $"Type '($name)' to continue: "
  if $answer != $name { die "aborted" }

  print $"==> Unmounting and wiping ($dev)"
  for part in (^lsblk -lnpo NAME $dev | lines | skip 1) {
    if (^findmnt -rno TARGET -S $part | complete).exit_code == 0 {
      ^umount $part
    }
    try { ^wipefs --all --quiet $part }
  }
  ^wipefs --all --quiet $dev

  print "==> Writing the ISO"
  ^dd $"if=($iso)" $"of=($dev)" bs=4M conv=fsync oflag=direct status=progress
  ^sync
  # Let the kernel see the image's partitions (some devices can't, harmless).
  try { ^blockdev --rereadpt $dev e> /dev/null }

  print "==> Verifying"
  if (^cmp -n $iso_size $iso $dev | complete).exit_code != 0 {
    die $"verification failed: ($dev) differs from the ISO"
  }

  print $"==> Done. ($dev) is ready to boot:"
  ^lsblk -o NAME,SIZE,FSTYPE,LABEL $dev
}
