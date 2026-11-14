# Install one of the hosts bundled on the ISO.
#
# Missing host or disk are picked from a list. Unless --no-vpn is given and if
# Mullvad isn't connected yet: connect the network (nmtui), log in to Mullvad,
# download its relay list and connect with lockdown mode on. The install itself
# is offline: each host's system and disk script are pre-built in
# $HOSTS_DIR/<host>/{system,disko}.
#
# Environment (set by the ISO): FLAKE, FLAKE_REV, HOSTS_DIR, USERNAME, REPO_URL.

def hosts [] {
  ls $env.HOSTS_DIR | get name | path basename | sort
}

def die [message: string] {
  print -e $message
  exit 1
}

def usage [] {
  print -e "usage: install-nixos [--no-vpn] [host] [disk]"
  print -e $"  hosts: (hosts | str join ' ')"
  print -e "  disks:"
  print -e (^lsblk -d -o NAME,SIZE,MODEL,TYPE)
  exit 1
}

def interactive [] {
  is-terminal --stdin
}

# Pick one of `options` from a list; a single option is picked automatically.
def pick [prompt: string, options: list<string>] {
  if ($options | length) == 1 {
    print $"($prompt): ($options.0) \(only option\)"
    return $options.0
  }
  let choice = $options | input list $prompt
  if ($choice | is-empty) { die "nothing selected" }
  $choice
}

# Whole disks to offer, without the USB stick the installer booted from.
def installable-disks [] {
  let iso = ^findmnt -no SOURCE /iso | complete
  let live = if $iso.exit_code == 0 {
    let source = $iso.stdout | str trim
    let parent = ^lsblk -no PKNAME $source | lines | get 0? | default ""
    if ($parent | is-empty) { $source } else { $"/dev/($parent)" }
  } else {
    ""
  }
  ^lsblk --json -d -p -o NAME,TYPE,SIZE,MODEL
  | from json
  | get blockdevices
  | where type == "disk" and name != $live and not ($it.name | str starts-with "/dev/zram")
}

def mullvad-connected [] {
  (^mullvad status | complete).stdout | lines | get 0? | $in == "Connected"
}

def mullvad-logged-in [] {
  (^mullvad account get | complete).stdout | str starts-with "Mullvad account:"
}

# Network -> login -> relay list -> lockdown + auto-connect -> connect.
def setup-mullvad [] {
  if (mullvad-connected) { return }

  if not (interactive) {
    print -e "Mullvad is not connected and there is no terminal to set it up."
    die "Run install-nixos interactively, or pass --no-vpn to install over the real IP."
  }

  print "==> Mullvad is not connected, setting it up"
  while (^ip route show default | str trim | is-empty) {
    print "No network. Opening nmtui: choose 'Activate a connection' and pick your network."
    input "Press Enter to continue (Ctrl-C to abort) "
    try { ^nmtui }
  }

  while not (mullvad-logged-in) {
    try { ^mullvad account login } catch { print -e "login failed, try again" }
  }

  # The package has no built-in relay list and a fresh daemon hasn't
  # downloaded one yet; connecting before it has fails with "Failure to
  # select a matching tunnel relay".
  print "==> Downloading the Mullvad relay list"
  ^mullvad relay update | ignore
  mut relays = ""
  for _ in 1..120 {
    $relays = (^mullvad relay list | complete).stdout | str trim
    if ($relays | is-not-empty) { break }
    sleep 1sec
  }
  if ($relays | is-empty) {
    die "The Mullvad relay list didn't download within 2 minutes; check the network and try again."
  }

  ^mullvad lockdown-mode set on
  ^mullvad auto-connect set on
  print "==> Connecting"
  # --wait prints every tunnel state change (several for one connection);
  # show only the final status below.
  try { ^mullvad connect --wait o> /dev/null }
  if not (mullvad-connected) {
    print -e "Mullvad did not connect:"
    print -e (^mullvad status | complete).stdout
    exit 1
  }
  ^mullvad status
}

def main [
  host?: string # a host bundled on the ISO, e.g. x16-disko
  disk?: string # the whole disk to ERASE and install onto, e.g. /dev/nvme0n1
  --no-vpn # install without a Mullvad connection (network access uses the real IP)
] {
  if not (is-admin) { die "run as root (sudo -i)" }

  if ($host == null or $disk == null) and not (interactive) { usage }

  let host = if $host == null { pick "Host to install" (hosts) } else { $host }
  if $host not-in (hosts) {
    die $"unknown host '($host)', available: (hosts | str join ' ')"
  }

  let disk = if $disk == null {
    let disks = installable-disks
    if ($disks | is-empty) { die "no disks found" }
    let labels = $disks | each { $"($in.name)  ($in.size) ($in.model? | default '')" | str trim }
    pick "Disk to ERASE and install onto" $labels | split row " " | first
  } else {
    $disk
  }
  if (^test -b $disk | complete).exit_code != 0 {
    print -e $"($disk) is not a block device"
    usage
  }

  if not $no_vpn { setup-mullvad }

  print $"==> Partitioning ($disk) \(this ERASES it; you'll be asked to confirm and for the LUKS passphrase\)"
  # The pre-built disk script targets /run/install-target.
  ^ln -sfn $disk /run/install-target
  run-external $"($env.HOSTS_DIR)/($host)/disko/bin/disko-destroy-format-mount"

  print $"==> Installing ($host) \(offline, from the ISO\)"
  # Resolve the link to the system's own store path: given a path inside
  # $HOSTS_DIR, nix points the new system profile at the whole hosts directory,
  # which has no `activate`, and installing the bootloader fails.
  let system = ^readlink -f $"($env.HOSTS_DIR)/($host)/system" | str trim
  # Everything is in the ISO's store; with no substituters, nixos-install copies
  # it from there and never contacts a binary cache.
  ^nixos-install --system $system --no-root-passwd --no-channel-copy --option substituters ""

  let home = $"/home/($env.USERNAME)"
  print $"==> Copying config to ($home)/nixos-config \(no network\)"
  # The ISO carries the flake source without .git history. Set up an empty repo
  # pointing at the remote; once a VPN is up, `git fetch` + `git reset` attaches
  # the history without touching the files.
  let target = $"/mnt($home)/nixos-config"
  ^cp -r --no-preserve=mode $"($env.FLAKE)/." $target
  ^git -C $target init -q
  ^git -C $target remote add origin $env.REPO_URL
  ^nixos-enter --root /mnt -c $"chown -R ($env.USERNAME):users ($home)/nixos-config"

  if not $no_vpn {
    # Carry the login and settings (lockdown, auto-connect) over, so the new
    # system boots logged in to the same Mullvad device. The daemon recreates
    # the directory if it isn't root-owned and private.
    print "==> Copying Mullvad login and settings"
    ^install -d -m 700 -o root -g root /mnt/etc/mullvad-vpn
    ^cp -p /etc/mullvad-vpn/settings.json /etc/mullvad-vpn/device.json /mnt/etc/mullvad-vpn/
    # The relay list too, so the first connection doesn't wait for a download.
    if ("/var/cache/mullvad-vpn/relays.json" | path exists) {
      ^install -d -m 755 /mnt/var/cache/mullvad-vpn
      ^cp -p /var/cache/mullvad-vpn/relays.json /mnt/var/cache/mullvad-vpn/
    }
  }

  print $"==> Set the password for ($env.USERNAME)"
  mut password_set = false
  while not $password_set {
    $password_set = try { ^nixos-enter --root /mnt -c $"passwd ($env.USERNAME)"; true } catch { false }
  }

  print "==> Done. Reboot and remove the installer USB stick."
  if not $no_vpn {
    print "    Don't run 'mullvad account logout' here: it would revoke the device"
    print "    the new system now uses."
  }
  print "    Once the VPN is up, link the config to its git history:"
  print $"    cd ~/nixos-config; git fetch origin; git reset ($env.FLAKE_REV)"
}
