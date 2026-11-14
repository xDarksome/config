# Usage: install-nixos [--no-vpn] [host] [disk]
#   host      a host bundled on the ISO, e.g. x16-disko
#   disk      the whole disk to ERASE and install onto, e.g. /dev/nvme0n1
#   --no-vpn  install without a Mullvad connection (downloads use the real IP)
# Missing host or disk are asked for interactively. If Mullvad isn't
# connected, the script connects the network (nmtui), logs in to Mullvad and
# connects with lockdown mode on. The install itself is offline: each host's
# system and disk script are pre-built in $HOSTS_DIR/<host>/{system,disko}.
#
# Environment (set by the ISO): FLAKE, FLAKE_REV, HOSTS_DIR, USERNAME, REPO_URL.

mapfile -t hosts < <(ls "$HOSTS_DIR")

usage() {
  echo "usage: install-nixos [--no-vpn] [host] [disk]" >&2
  echo "  hosts: ${hosts[*]}" >&2
  echo "  disks:" >&2
  lsblk -d -o NAME,SIZE,MODEL,TYPE >&2
  exit 1
}

interactive() { [[ -t 0 ]]; }

# pick <prompt> <option>... : sets $picked. Auto-picks a single option.
pick() {
  local prompt=$1
  shift
  if [[ $# -eq 1 ]]; then
    picked=$1
    echo "$prompt: $picked (only option)"
    return
  fi
  local PS3="$prompt (number): "
  select picked in "$@"; do
    [[ -n $picked ]] && return
    echo "invalid choice" >&2
  done
  exit 1 # EOF
}

# Whole disks to offer, without the USB stick the installer booted from.
installable_disks() {
  local live
  live=$(findmnt -no SOURCE /iso 2>/dev/null || true)
  if [[ -n $live ]]; then
    live=/dev/$(lsblk -no PKNAME "$live" | head -n1)
    [[ $live == /dev/ ]] && live=$(findmnt -no SOURCE /iso)
  fi
  lsblk -dnpo NAME,TYPE | awk '$2 == "disk" { print $1 }' |
    grep -v -e '^/dev/zram' -e "^${live:-none}\$" || true
}

# Capture output before matching: with pipefail, `cmd | grep -q` fails when
# grep exits early and cmd gets SIGPIPE, even though it matched.
mullvad_connected() {
  local status
  status=$(mullvad status 2>/dev/null || true)
  [[ ${status%%$'\n'*} == Connected ]]
}

mullvad_logged_in() {
  local account
  account=$(mullvad account get 2>/dev/null || true)
  [[ $account == "Mullvad account:"* ]]
}

# Network -> login -> lockdown + auto-connect -> connect.
setup_mullvad() {
  mullvad_connected && return

  if ! interactive; then
    echo "Mullvad is not connected and there is no terminal to set it up." >&2
    echo "Run install-nixos interactively, or pass --no-vpn to install over the real IP." >&2
    exit 1
  fi

  echo "==> Mullvad is not connected, setting it up"
  until [[ -n $(ip route show default) ]]; do
    echo "No network. Opening nmtui: choose 'Activate a connection' and pick your network."
    read -rp "Press Enter to continue (Ctrl-C to abort) "
    nmtui || true
  done

  until mullvad_logged_in; do
    mullvad account login || echo "login failed, try again" >&2
  done

  mullvad lockdown-mode set on
  mullvad auto-connect set on
  echo "==> Connecting"
  mullvad connect --wait
  if ! mullvad_connected; then
    echo "Mullvad did not connect:" >&2
    mullvad status >&2
    exit 1
  fi
  mullvad status
}

vpn=1
if [[ ${1:-} == --no-vpn ]]; then
  vpn=0
  shift
fi
[[ $# -le 2 ]] || usage
host=${1:-}
disk=${2:-}

[[ $EUID -eq 0 ]] || { echo "run as root (sudo -i)" >&2; exit 1; }

if [[ -z $host || -z $disk ]] && ! interactive; then
  usage
fi

if [[ -z $host ]]; then
  pick "Host to install" "${hosts[@]}"
  host=$picked
fi
if [[ ! -d $HOSTS_DIR/$host ]]; then
  echo "unknown host '$host', available: ${hosts[*]}" >&2
  exit 1
fi

if [[ -z $disk ]]; then
  mapfile -t disks < <(installable_disks)
  [[ ${#disks[@]} -gt 0 ]] || { echo "no disks found" >&2; exit 1; }
  labels=()
  for d in "${disks[@]}"; do
    labels+=("$d  $(lsblk -dno SIZE,MODEL "$d" | xargs)")
  done
  pick "Disk to ERASE and install onto" "${labels[@]}"
  disk=${picked%% *}
fi
[[ -b $disk ]] || { echo "$disk is not a block device" >&2; usage; }

if [[ $vpn -eq 1 ]]; then
  setup_mullvad
fi

echo "==> Partitioning $disk (this ERASES it; you'll be asked to confirm and for the LUKS passphrase)"
# The pre-built disk script targets /run/install-target.
ln -sfn "$disk" /run/install-target
"$HOSTS_DIR/$host/disko/bin/disko-destroy-format-mount"

echo "==> Installing $host (offline, from the ISO)"
# Everything is in the ISO's store; with no substituters, nixos-install copies
# it from there and never contacts a binary cache.
nixos-install --system "$HOSTS_DIR/$host/system" --no-root-passwd --no-channel-copy \
  --option substituters ""

echo "==> Copying config to /home/$USERNAME/nixos-config (no network)"
# The ISO carries the flake source without .git history. Set up an empty repo
# pointing at the remote; once a VPN is up, `git fetch` + `git reset` attaches
# the history without touching the files.
target=/mnt/home/$USERNAME/nixos-config
cp -r --no-preserve=mode "$FLAKE/." "$target"
git -C "$target" init -q
git -C "$target" remote add origin "$REPO_URL"
nixos-enter --root /mnt -c "chown -R $USERNAME:users /home/$USERNAME/nixos-config"

if [[ $vpn -eq 1 ]]; then
  # Carry the login and settings (lockdown, auto-connect) over, so the new
  # system boots logged in to the same Mullvad device. The daemon recreates the
  # directory if it isn't root-owned and private.
  echo "==> Copying Mullvad login and settings"
  install -d -m 700 -o root -g root /mnt/etc/mullvad-vpn
  cp -p /etc/mullvad-vpn/settings.json /etc/mullvad-vpn/device.json /mnt/etc/mullvad-vpn/
fi

echo "==> Set the password for $USERNAME"
until nixos-enter --root /mnt -c "passwd $USERNAME"; do :; done

echo "==> Done. Reboot and remove the installer USB stick."
if [[ $vpn -eq 1 ]]; then
  echo "    Don't run 'mullvad account logout' here: it would revoke the device"
  echo "    the new system now uses."
fi
echo "    Once the VPN is up, link the config to its git history:"
echo "    cd ~/nixos-config && git fetch origin && git reset $FLAKE_REV"
