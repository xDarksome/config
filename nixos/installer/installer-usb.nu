# installer-usb /dev/sdX: write the installer ISO to a USB stick.
# A Nushell command in the dev shell (nix develop).
#
# The ISO is a hybrid image: it carries its own partition table and
# filesystems, laid out the way the NixOS boot setup expects. So the stick is
# partitioned and formatted by writing the image to the whole device; before
# that, any old partitions are unmounted and their signatures wiped, and
# afterwards the stick is read back and compared with the ISO.

const flake = path self ../..

def die [message: string] {
  error make --unspanned {msg: $message}
}

def mib [bytes: int] {
  $bytes // 1024 // 1024
}

# Runs a command as root: directly when already root, otherwise with sudo.
def --wrapped root [...command] {
  if (is-admin) { run-external ...$command } else { ^sudo ...$command }
}

# Write the installer ISO to a USB stick (builds the ISO first)
export def main [
  device: string # the whole disk to write to, e.g. /dev/sdb
  --force # allow a disk that isn't USB or removable (or a loop device)
] {
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

  print "==> Building the ISO"
  let iso_dir = ^nix build $"($flake)#installer-iso" --no-link --print-out-paths | str trim
  let iso = glob $"($iso_dir)/iso/*.iso" | first

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
      root umount $part
    }
    try { root wipefs --all --quiet $part }
  }
  root wipefs --all --quiet $dev

  print "==> Writing the ISO"
  root dd $"if=($iso)" $"of=($dev)" bs=4M conv=fsync oflag=direct status=progress
  ^sync
  # Let the kernel see the image's partitions (some devices can't, harmless).
  try { root blockdev --rereadpt $dev e> /dev/null }

  print "==> Verifying"
  if (root cmp -n $iso_size $iso $dev | complete).exit_code != 0 {
    die $"verification failed: ($dev) differs from the ISO"
  }

  print $"==> Done. ($dev) is ready to boot:"
  ^lsblk -o NAME,SIZE,FSTYPE,LABEL $dev
}
