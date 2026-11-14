# Interactive VM for trying the installer ISO by hand. See installer-vm.nix.
# Environment (set at the top of the script): ISO_DIR, OVMF_CODE, OVMF_VARS.

def main [
  mode: string = "iso" # iso: boot the ISO, disk: boot the installed disk, reset: delete the VM's state
] {
  let dir = $env.INSTALLER_VM_DIR? | default ".installer-vm"

  if $mode == "reset" {
    rm -rf $dir
    print $"removed ($dir)"
    return
  }
  if $mode not-in ["iso" "disk"] {
    print -e "usage: installer-vm [iso|disk|reset]"
    exit 1
  }

  mkdir $dir
  let disk = $"($dir)/disk.qcow2"
  let vars = $"($dir)/OVMF_VARS.fd"
  # x16's closure is large; the image is sparse, so this costs only what's used.
  if not ($disk | path exists) { ^qemu-img create -q -f qcow2 $disk 64G }
  # Writable EFI variables: the installed system registers its boot entry.
  if not ($vars | path exists) { ^install -m 644 $env.OVMF_VARS $vars }

  let accel = if (^test -w /dev/kvm | complete).exit_code == 0 {
    [-enable-kvm -cpu host]
  } else {
    print -e "warning: /dev/kvm not available, the VM will be very slow"
    [-cpu max]
  }

  let cdrom = if $mode == "iso" {
    let iso = glob $"($env.ISO_DIR)/iso/*.iso" | first
    [-drive $"media=cdrom,readonly=on,file=($iso)" -boot order=d]
  } else {
    []
  }

  (exec qemu-system-x86_64
    -machine q35 ...$accel -smp 4 -m 8G
    -drive $"if=pflash,format=raw,unit=0,readonly=on,file=($env.OVMF_CODE)"
    -drive $"if=pflash,format=raw,unit=1,file=($vars)"
    -drive $"if=none,id=disk,format=qcow2,file=($disk)"
    -device nvme,drive=disk,serial=installer-vm
    ...$cdrom
    -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22
    -device virtio-net-pci,netdev=net0
    -device virtio-vga)
}
