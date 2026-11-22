-- Hyprland (pc only). The shortcuts are ported from the COSMIC ones in
-- nixos/cosmic/config/com.system76.CosmicSettings.Shortcuts/v1/custom; the
-- keyboard and mouse settings from .../com.system76.CosmicComp/v1.
-- Check after editing: Hyprland --verify-config -c ~/.config/hypr/hyprland.lua

local mod = "SUPER"

local terminal = "cosmic-term"
local launcher = "fuzzel"
local lock = "hyprlock"
local screenshot = 'grim -g "$(slurp)" - | wl-copy'

-- Every monitor at its highest refresh rate. Among modes with that rate it
-- takes the highest resolution, so a monitor that only reaches its top rate
-- at a lower resolution runs at that resolution.
hl.monitor({
    output   = "",
    mode     = "highrr",
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

        -- No mouse acceleration: pointer speed follows the mouse 1:1.
        accel_profile = "flat",
        sensitivity   = 0,
    },
})

-- The 4K monitor is scaled 2x, so the desktop is 1920x1080 in logical
-- pixels. XWayland apps (most Proton games) would see that size and be
-- upscaled; render them at the native resolution instead. That makes the
-- X11 Steam client tiny, so scale its UI back up itself.
hl.config({
    xwayland = {
        force_zero_scaling = true,
    },
})
hl.env("STEAM_FORCE_DESKTOPUI_SCALING", "2")

hl.config({
    general = {
        gaps_in  = 0,
        gaps_out = 0,
    },
    animations = {
        enabled = false,
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
        -- No tearing: the monitor hangs off the iGPU's USB-C while games
        -- render on the RX 9070 XT, and with tearing allowed, fullscreen games
        -- were capped at ~60 FPS. Without it, direct scanout works.
        allow_tearing = false,
    },
    render = {
        -- Fullscreen windows go straight to the display, skipping composition.
        direct_scanout = 1,
    },
    cursor = {
        -- Moving the cursor doesn't knock a fullscreen game out of VRR.
        no_break_fs_vrr = 1,
        -- Draw the cursor into the frame instead of on the iGPU's cursor
        -- plane: across the two GPUs, the hardware cursor kept the previous
        -- window's cursor shape after switching windows.
        no_hardware_cursors = 1,
    },
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
