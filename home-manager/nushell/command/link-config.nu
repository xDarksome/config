# link-config: attach the config checkout to its git history on GitHub.
#
# install-nixos copies the config to ~/nixos-config without history (the ISO
# has no network): an empty repo with `origin` set, and the commit the ISO was
# built from in `git config nixos-config.install-rev`. This fetches origin and
# points the repo at that commit without touching the files, so anything that
# differs from it shows up as uncommitted changes. The fetch only goes out
# while Mullvad is connected, so the repo is never pulled from the real IP.

# The config checkout (config.nu sets $env.CONFIG_DIR).
def repo [] { $env.CONFIG_DIR? | default ($env.HOME | path join nixos-config) }

def die [message: string] {
  error make --unspanned {msg: $message}
}

def --wrapped git [...args] {
  ^git -C (repo) ...$args
}

def ok [result] { $result.exit_code == 0 }

# Link ~/nixos-config, as copied by install-nixos, to its history on GitHub
export def main [
  --allow-real-ip # fetch even when Mullvad isn't connected
] {
  if not (repo | path join .git | path exists) {
    die $"(repo) is not a git repository"
  }
  if (ok (git rev-parse --quiet --verify HEAD | complete)) {
    print $"(repo) is already linked:"
    git status --short --branch
    return
  }
  if not $allow_real_ip {
    let status = ^mullvad status | complete
    if ($status.stdout | lines | get 0? | default "") != "Connected" {
      die "Mullvad isn't connected. Connect first, or pass --allow-real-ip."
    }
  }

  print "==> Fetching origin"
  git fetch origin
  git remote set-head origin --auto | ignore
  # e.g. origin/main
  let upstream = git symbolic-ref --short refs/remotes/origin/HEAD | str trim
  let branch = $upstream | str replace "origin/" ""

  # A dirty tree records "<rev>-dirty"; its changes show up as modifications.
  let rev = git config --get nixos-config.install-rev | complete | get stdout | str trim | str replace -r '-dirty$' ''
  let known = $rev not-in ["" "unknown"] and (ok (git cat-file -e $"($rev)^{commit}" | complete))
  let target = if $known {
    $rev
  } else {
    let why = if $rev in ["" "unknown"] { "no install commit recorded" } else { $"($rev) is not on origin \(never pushed?\)" }
    print -e $"warning: ($why); attaching to ($upstream) instead. Differences show up as uncommitted changes."
    $upstream
  }

  print $"==> Attaching to ($target) on ($branch)"
  # The repo has no commits yet, so HEAD points at an unborn branch: name it
  # after origin's default, then move it to the target. --mixed keeps the files.
  git symbolic-ref HEAD $"refs/heads/($branch)"
  git reset --quiet --mixed $target
  git branch --quiet --set-upstream-to $upstream
  git status --short --branch
}
