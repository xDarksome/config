-- Hyprland (pc only). The shortcuts are ported from the COSMIC ones in
-- nixos/cosmic/config/com.system76.CosmicSettings.Shortcuts/v1/custom; the
-- keyboard and mouse settings from .../com.system76.CosmicComp/v1.
-- Check after editing: Hyprland --verify-config -c ~/.config/hypr/hyprland.lua

local mod = "SUPER"

local terminal = "cosmic-term"
local launcher = "fuzzel"
local lock = "hyprlock"
local screenshot = 'grim -g "$(slurp)" - | wl-copy'

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

hl.config({
    input = {
        kb_model   = "pc104",
        kb_layout  = "us,ru",
        -- Super+Space switches the layout.
        kb_options = "grp:win_space_toggle",

        repeat_delay = 350,
        repeat_rate  = 25,

        accel_profile = "adaptive",
        sensitivity   = -0.1,
    },
})

hl.config({
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,

        -- Variable refresh rate for fullscreen windows (2); always on (1) can
        -- flicker on the desktop with some monitors.
        vrr = 2,
    },
})

-- Gaming latency
hl.config({
    general = {
        -- Lets windows with the `immediate` rule below skip vsync and present
        -- frames as soon as they're ready (tearing only above the refresh rate
        -- when VRR is on).
        allow_tearing = true,
    },
    render = {
        -- Fullscreen windows go straight to the display, skipping composition.
        direct_scanout = 1,
    },
    cursor = {
        -- Moving the cursor doesn't knock a fullscreen game out of VRR.
        no_break_fs_vrr = 1,
    },
})

-- Steam games (native and Proton) are steam_app_<id>.
hl.window_rule({
    match     = { class = "^steam_app_.*$" },
    immediate = true,
})

-- Apps
hl.bind(mod .. " + N", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + C", hl.dsp.exec_cmd(launcher))
hl.bind(mod .. " + L", hl.dsp.exec_cmd(lock))
hl.bind(mod .. " + P", hl.dsp.exec_cmd(screenshot))

-- Windows
hl.bind(mod .. " + B", hl.dsp.window.close())
hl.bind(mod .. " + F", hl.dsp.window.fullscreen())
-- COSMIC's "Terminate": end the session.
hl.bind(mod .. " + CTRL + Escape", hl.dsp.exit())

-- Focus and move, on h/t/d/s (left/down/up/right).
local directions = { H = "left", T = "down", D = "up", S = "right" }
for key, direction in pairs(directions) do
    hl.bind(mod .. " + " .. key,          hl.dsp.focus({ direction = direction }))
    hl.bind(mod .. " + CTRL + " .. key,   hl.dsp.window.move({ direction = direction }))
end

-- Workspaces 1-9 on i e a y o u x j k; with Ctrl, move the window there.
local workspaces = { "I", "E", "A", "Y", "O", "U", "X", "J", "K" }
for i, key in ipairs(workspaces) do
    hl.bind(mod .. " + " .. key,        hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + CTRL + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Drag and resize floating windows with the mouse.
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
