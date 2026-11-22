# Writes the KWin/Plasma settings: the COSMIC shortcuts (as in
# home-manager/hyprland/hyprland.lua and home-manager/sway), 9 virtual desktops
# and the keyboard settings. Plasma keeps rewriting these files itself, so
# they're set key by key with kwriteconfig6 on every home-manager activation,
# not linked read-only; anything else you change in System Settings stays.
#
# kglobalshortcutsrc entries are "active,default,name" ("none" for no keys;
# several keys are tab-separated). App launchers live under
# [services][<app>.desktop], with just the keys.

def shortcut [keys: string, name: string] {
  $"($keys),none,($name)"
}

def main [kwriteconfig: string] {
  let directions = [
    [key focus quick_tile];
    [H "Switch Window Left" "Window Quick Tile Left"]
    [T "Switch Window Down" "Window Quick Tile Bottom"]
    [D "Switch Window Up" "Window Quick Tile Top"]
    [S "Switch Window Right" "Window Quick Tile Right"]
  ]
  let workspace_keys = [I E A Y O U X J K]

  let kwin = (
    # Focus with Super+h/t/d/s; with Ctrl, tile the window to that side (KWin
    # doesn't tile automatically, so this is the closest to COSMIC's "move").
    ($directions | each {|d| [
      [$d.focus (shortcut $"Meta+($d.key)" $d.focus)]
      [$d.quick_tile (shortcut $"Meta+Ctrl+($d.key)" $d.quick_tile)]
    ]} | flatten)
    # Desktops 1-9 on i e a y o u x j k; with Ctrl, move the window there.
    ++ ($workspace_keys | enumerate | each {|w|
      let n = $w.index + 1
      [
        [$"Switch to Desktop ($n)" (shortcut $"Meta+($w.item)" $"Switch to Desktop ($n)")]
        [$"Window to Desktop ($n)" (shortcut $"Meta+Ctrl+($w.item)" $"Window to Desktop ($n)")]
      ]
    } | flatten)
    ++ [
      ["Window Close" (shortcut "Meta+B" "Close Window")]
      ["Window Fullscreen" (shortcut "Meta+F" "Make Window Fullscreen")]
      # KWin defaults on the keys above, cleared so they don't take them.
      ["Show Desktop" "none,none,Peek at Desktop"]
      ["Edit Tiles" "none,none,Toggle Tiles Editor"]
      ["Kill Window" "none,none,Kill Window"]
      ["Activate Window Demanding Attention" "none,none,Activate Window Demanding Attention"]
      ["Invert" "none,none,Toggle Invert Effect"]
      ["InvertWindow" "none,none,Toggle Invert Effect on Window"]
      ["ToggleCurrentThumbnail" "none,none,Toggle Thumbnail for Current Window"]
    ]
  )

  let entries = (
    ($kwin | each {|e| {file: kglobalshortcutsrc, groups: [kwin], key: $e.0, value: $e.1}})
    ++ [
      {file: kglobalshortcutsrc, groups: [ksmserver], key: "Lock Session", value: "Meta+L\tScreensaver,none,Lock Session"}
      # COSMIC's "Terminate": end the session.
      {file: kglobalshortcutsrc, groups: [ksmserver], key: "Log Out Without Confirmation", value: "Meta+Ctrl+Esc,none,Log Out Without Confirmation"}
      {file: kglobalshortcutsrc, groups: [services com.system76.CosmicTerm.desktop], key: _launch, value: "Meta+N"}
      # KRunner as the launcher (Super+C), keeping its own defaults too.
      {file: kglobalshortcutsrc, groups: [services org.kde.krunner.desktop], key: _launch, value: "Meta+C\tAlt+Space\tAlt+F2\tSearch"}
      {file: kglobalshortcutsrc, groups: [services org.kde.spectacle.desktop], key: RectangularRegionScreenShot, value: "Meta+P\tMeta+Shift+Print"}
      # Meta+P is KScreen's display switcher by default.
      {file: kglobalshortcutsrc, groups: [services org.kde.kscreen.desktop], key: ShowOSD, value: "Display"}

      # Super on its own does nothing (as in COSMIC), instead of opening the
      # application launcher.
      {file: kwinrc, groups: [ModifierOnlyShortcuts], key: Meta, value: ""}
      {file: kwinrc, groups: [Desktops], key: Number, value: "9"}
      {file: kwinrc, groups: [Desktops], key: Rows, value: "1"}

      {file: kxkbrc, groups: [Layout], key: Use, value: "true"}
      {file: kxkbrc, groups: [Layout], key: Model, value: "pc104"}
      {file: kxkbrc, groups: [Layout], key: LayoutList, value: "us,ru"}
      {file: kxkbrc, groups: [Layout], key: VariantList, value: ","}
      # Super+Space switches the layout.
      {file: kxkbrc, groups: [Layout], key: Options, value: "grp:win_space_toggle"}
      {file: kxkbrc, groups: [Layout], key: ResetOldOptions, value: "true"}
      {file: kcminputrc, groups: [Keyboard], key: RepeatDelay, value: "350"}
      {file: kcminputrc, groups: [Keyboard], key: RepeatRate, value: "25"}
    ]
  )

  for e in $entries {
    let groups = $e.groups | each {|g| [--group $g]} | flatten
    ^$kwriteconfig --file $e.file ...$groups --key $e.key $e.value
  }
}
