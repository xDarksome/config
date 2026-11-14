# Interactive VM for trying the installer ISO by hand. See installer-vm.nix.
# Environment (set by the wrapper): ISO_DIR, OVMF_CODE, OVMF_VARS.

dir=${INSTALLER_VM_DIR:-.installer-vm}
mode=${1:-iso}

case $mode in
  reset)
    rm -rf "$dir"
    echo "removed $dir"
    exit 0
    ;;
  iso | disk) ;;
  *)
    echo "usage: installer-vm [iso|disk|reset]" >&2
    exit 1
    ;;
esac

mkdir -p "$dir"
# x16's closure is large; the image is sparse, so this costs only what's used.
[[ -f $dir/disk.qcow2 ]] || qemu-img create -q -f qcow2 "$dir/disk.qcow2" 64G
# Writable EFI variables: the installed system registers its boot entry.
[[ -f $dir/OVMF_VARS.fd ]] || install -m 644 "$OVMF_VARS" "$dir/OVMF_VARS.fd"

accel=(-cpu max)
if [[ -w /dev/kvm ]]; then
  accel=(-enable-kvm -cpu host)
else
  echo "warning: /dev/kvm not available, the VM will be very slow" >&2
fi

cdrom=()
if [[ $mode == iso ]]; then
  isos=("$ISO_DIR"/iso/*.iso)
  cdrom=(-drive "media=cdrom,readonly=on,file=${isos[0]}" -boot order=d)
fi

exec qemu-system-x86_64 \
  -machine q35 "${accel[@]}" -smp 4 -m 8G \
  -drive "if=pflash,format=raw,unit=0,readonly=on,file=$OVMF_CODE" \
  -drive "if=pflash,format=raw,unit=1,file=$dir/OVMF_VARS.fd" \
  -drive "if=none,id=disk,format=qcow2,file=$dir/disk.qcow2" \
  -device nvme,drive=disk,serial=installer-vm \
  "${cdrom[@]}" \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22 \
  -device virtio-net-pci,netdev=net0 \
  -device virtio-vga
