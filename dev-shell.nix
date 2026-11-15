# nix develop: tools for working on this config, and these Nushell commands:
#   installer-usb /dev/sdX    write the installer ISO to a USB stick
#   installer-vm [disk|reset] try the installer ISO in a VM
#
# The commands are loaded through Nushell's vendor autoload: mkShell adds every
# package's share/ to XDG_DATA_DIRS, and an interactive `nu` loads
# share/nushell/vendor/autoload/*.nu from there. So they're there in any `nu`
# started in the dev shell, e.g. `nix develop --command nu`. They're copies made
# when the shell is entered, so edits apply the next time you enter it.
{pkgs}: let
  commands =
    pkgs.runCommand "dev-commands" {
      nativeBuildInputs = [pkgs.nushell];
      scripts = [./nixos/installer/installer-usb.nu ./tests/installer-vm.nu];
    } ''
      dir=$out/share/nushell/dev-commands
      autoload=$out/share/nushell/vendor/autoload/dev-commands.nu
      mkdir -p $dir $(dirname $autoload)
      for f in $scripts; do
        name=$(stripHash $f)
        install -m 644 $f $dir/$name
        nu --no-config-file --commands "nu-check --debug --as-module '$dir/$name'" >/dev/null
        echo "use $dir/$name" >> $autoload
      done
    '';
in
  pkgs.mkShell {
    packages = with pkgs; [
      pmbootstrap
      nushell
      commands
      # installer-usb
      coreutils
      util-linux
      diffutils
      # installer-vm
      qemu_kvm
    ];

    OVMF_CODE = pkgs.OVMF.firmware;
    OVMF_VARS = pkgs.OVMF.variables;

    # The commands build from, and keep the VM in, the checkout itself, not
    # the copy of it in the Nix store.
    shellHook = ''
      export CONFIG_FLAKE=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    '';

    passthru = {inherit commands;};
  }
