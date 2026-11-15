# installer-vm: try the installer ISO by hand in a VM. QEMU and the UEFI
# firmware are fetched when it runs, from the nixpkgs the config pins.
#
#   installer-vm          boot the ISO (disk attached); builds the ISO first
#   installer-vm disk     boot the installed disk
#   installer-vm reset    delete the VM disk and EFI variables
#
# The disk is NVMe, so it shows up as /dev/nvme0n1 like on the laptop, and the
# x16 initrd (which has no virtio drivers) can find it.
# SSH into the VM: ssh -p 2222 root@localhost (live ISO, your key)
# State lives in $env.INSTALLER_VM_DIR (default: .installer-vm in the config checkout).

# The config checkout (config.nu sets $env.CONFIG_DIR).
def flake [] { $env.CONFIG_DIR? | default ($env.HOME | path join nixos-config) }

# Builds (or fetches from the cache) a package from the config's nixpkgs.
def pkg [attr: string] {
  ^nix build --inputs-from (flake) $"nixpkgs#($attr)" --no-link --print-out-paths | str trim
}

# Try the installer ISO in a VM
export def main [
  mode: string = "iso" # iso: boot the ISO, disk: boot the installed disk, reset: delete the VM's state
] {
  let dir = $env.INSTALLER_VM_DIR? | default (flake | path join .installer-vm)

  if $mode == "reset" {
    rm -rf $dir
    print $"removed ($dir)"
    return
  }
  if $mode not-in ["iso" "disk"] {
    error make --unspanned {msg: "usage: installer-vm [iso|disk|reset]"}
  }

  print "==> Fetching QEMU and the UEFI firmware"
  let qemu = pkg "qemu_kvm^out"
  let ovmf = pkg "OVMF.fd"
  let ovmf_code = $"($ovmf)/FV/OVMF_CODE.fd"

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
    print "==> Building the ISO"
    let iso_dir = ^nix build $"(flake)#installer-iso" --no-link --print-out-paths | str trim
    let iso = glob $"($iso_dir)/iso/*.iso" | first
    [-drive $"media=cdrom,readonly=on,file=($iso)" -boot order=d]
  } else {
    []
  }

  (^$"($qemu)/bin/qemu-system-x86_64"
    -machine q35 ...$accel -smp 4 -m 8G
    -drive $"if=pflash,format=raw,unit=0,readonly=on,file=($ovmf_code)"
    -drive $"if=pflash,format=raw,unit=1,file=($vars)"
    -drive $"if=none,id=disk,format=qcow2,file=($disk)"
    -device nvme,drive=disk,serial=installer-vm
    ...$cdrom
    -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22
    -device virtio-net-pci,netdev=net0
    -device virtio-vga)
}
