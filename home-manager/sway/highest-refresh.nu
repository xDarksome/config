# Sets every sway output to its highest refresh rate and, among the modes with
# that rate, the highest resolution, like Hyprland's `highrr` monitor mode.
# Sway itself only takes an exact mode, so this runs at startup (and on
# reload) and picks one from `swaymsg -t get_outputs`.

def main [] {
  for output in (^swaymsg -t get_outputs --raw | from json) {
    let modes = $output.modes? | default []
    if ($modes | is-empty) { continue }
    # refresh is in mHz.
    let best = $modes | sort-by refresh width height | last
    let mode = $"($best.width)x($best.height)@($best.refresh / 1000)Hz"
    ^swaymsg output $output.name mode $mode | ignore
  }
}
