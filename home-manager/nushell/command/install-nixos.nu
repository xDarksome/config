# install-nixos: get the installer ISO onto a USB stick or into a VM.
#
#   install-nixos usb /dev/sdX   write the ISO to a USB stick
#   install-nixos vm             try the ISO in a VM (disk attached)
#   install-nixos vm disk        boot the VM's installed disk
#   install-nixos vm reset       delete the VM disk and EFI variables
#
# Both build the ISO from the config checkout first. (The ISO's own
# install-nixos, which installs a host, is nixos/installer/install-nixos.nu.)

# The config checkout (config.nu sets $env.CONFIG_DIR).
def flake [] { $env.CONFIG_DIR? | default ($env.HOME | path join nixos-config) }

def die [message: string] {
  error make --unspanned {msg: $message}
}

def mib [bytes: int] {
  $bytes // 1024 // 1024
}

# Builds the installer ISO and returns the .iso file.
def build-iso [] {
  print "==> Building the ISO"
  let dir = ^nix build $"(flake)#installer-iso" --no-link --print-out-paths | str trim
  glob $"($dir)/iso/*.iso" | first
}

# Builds (or fetches from the cache) a package from the config's nixpkgs.
def pkg [attr: string] {
  ^nix build --inputs-from (flake) $"nixpkgs#($attr)" --no-link --print-out-paths | str trim
}

# Runs a command as root: directly when already root, otherwise with sudo.
def --wrapped root [...command] {
  if (is-admin) { run-external ...$command } else { ^sudo ...$command }
}

# Write the installer ISO to a USB stick, or try it in a VM
export def main [] {
  print "Usage:
  install-nixos usb <device> [--force]   write the ISO to a USB stick
  install-nixos vm [iso|disk|reset]      try the ISO in a VM

Details: help install-nixos usb, help install-nixos vm"
}

# Write the installer ISO to a USB stick (builds the ISO first)
#
# The ISO is a hybrid image: it carries its own partition table and
# filesystems, laid out the way the NixOS boot setup expects. So the stick is
# partitioned and formatted by writing the image to the whole device; before
# that, any old partitions are unmounted and their signatures wiped, and
# afterwards the stick is read back and compared with the ISO.
export def usb [
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

  let iso = build-iso
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

# Try the installer ISO in a VM
#
# QEMU and the UEFI firmware are fetched when it runs, from the nixpkgs the
# config pins. The disk is NVMe, so it shows up as /dev/nvme0n1 like on the
# laptop, and the x16 initrd (which has no virtio drivers) can find it.
# SSH into the live ISO: ssh -p 2222 root@localhost (your key).
# State lives in $env.INSTALLER_VM_DIR (default: .installer-vm in the config
# checkout).
export def vm [
  mode: string = "iso" # iso: boot the ISO (builds it first), disk: boot the installed disk, reset: delete the VM's state
] {
  let dir = $env.INSTALLER_VM_DIR? | default (flake | path join .installer-vm)

  if $mode == "reset" {
    rm -rf $dir
    print $"removed ($dir)"
    return
  }
  if $mode not-in ["iso" "disk"] {
    die "usage: install-nixos vm [iso|disk|reset]"
  }

  print "==> Fetching QEMU and the UEFI firmware"
  let qemu = pkg "qemu_kvm^out"
  let ovmf = pkg "OVMF.fd"

  mkdir $dir
  let disk = $"($dir)/disk.qcow2"
  let vars = $"($dir)/OVMF_VARS.fd"
  # x16's closure is large; the image is sparse, so this costs only what's used.
  if not ($disk | path exists) { ^$"($qemu)/bin/qemu-img" create -q -f qcow2 $disk 64G }
  # Writable EFI variables: the installed system registers its boot entry.
  if not ($vars | path exists) { ^install -m 644 $"($ovmf)/FV/OVMF_VARS.fd" $vars }

  let accel = if (^test -w /dev/kvm | complete).exit_code == 0 {
    [-enable-kvm -cpu host]
  } else {
    print -e "warning: /dev/kvm not available, the VM will be very slow"
    [-cpu max]
  }

  let cdrom = if $mode == "iso" {
    let iso = build-iso
    [-drive $"media=cdrom,readonly=on,file=($iso)" -boot order=d]
  } else {
    []
  }

  (^$"($qemu)/bin/qemu-system-x86_64"
    -machine q35 ...$accel -smp 4 -m 8G
    -drive $"if=pflash,format=raw,unit=0,readonly=on,file=($ovmf)/FV/OVMF_CODE.fd"
    -drive $"if=pflash,format=raw,unit=1,file=($vars)"
    -drive $"if=none,id=disk,format=qcow2,file=($disk)"
    -device nvme,drive=disk,serial=installer-vm
    ...$cdrom
    -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22
    -device virtio-net-pci,netdev=net0
    -device virtio-vga)
}
