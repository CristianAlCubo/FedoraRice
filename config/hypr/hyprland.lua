        -- This is an example Hyprland Lua config file.
-- Refer to the wiki for more information.
-- https://wiki.hypr.land/Configuring/Start/

-- Please note not all available settings / options are set here.
-- For a full list, see the wiki

-- You can (and should!!) split this configuration into multiple files
-- Create your files separately and then require them like this:
-- require("myColors")


------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- La disposición de TUS monitores vive en ~/.config/hypr/monitors.lua (install.sh la crea una vez y
-- nunca la pisa). Aquí solo hay una regla comodín: cualquier pantalla no descrita allí se enciende
-- con su mejor tasa de refresco, a la derecha de las demás. Así nunca queda una pantalla en negro.
local HOME = os.getenv("HOME")
hl.monitor({ output = "", mode = "highrr", position = "auto", scale = 1 })

local ok_mon, MON = pcall(dofile, HOME .. "/.config/hypr/monitors.lua")
if not ok_mon or type(MON) ~= "table" then MON = {} end
for _, m in ipairs(MON.rules or {}) do hl.monitor(m) end


---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use
local terminal    = "kitty"
local fileManager = "nautilus"
local qs          = "qs -p " .. HOME .. "/.config/quickshell/bar"
local menu        = qs .. " ipc call launcher toggle"


-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
--
hl.on("hyprland.start", function ()
  -- Activa graphical-session.target: sin esto xdg-desktop-portal no arranca
  -- y las apps GTK/libadwaita no se enteran del tema oscuro.
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP DISPLAY HYPRLAND_INSTANCE_SIGNATURE && systemctl --user start hyprland-session.target")
  hl.exec_cmd("/usr/libexec/polkit-mate-authentication-agent-1")
  hl.exec_cmd(qs)
  hl.exec_cmd(HOME .. "/.config/hypr/scripts/wallpaper.sh apply")
  -- Spotify en segundo plano (la ventana va a special:spotify, oculta), solo si está instalado
  hl.exec_cmd("sp=$(command -v spotify || echo /var/lib/snapd/snap/bin/spotify); [ -x \"$sp\" ] && exec \"$sp\"")
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
hl.env("QS_ICON_THEME", "Papirus-Dark")   -- iconos de Quickshell (lanzador, bandeja, avisos)
hl.env("HYPRCURSOR_SIZE", "24")


-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Please note permission changes here require a Hyprland restart and are not applied on-the-fly
-- for security reasons

-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })

-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")


-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
-- Colores generados desde ~/.config/rice/theme.json (comando: rice-theme)
local theme = dofile(os.getenv("HOME") .. "/.config/hypr/colors.lua")

hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 6,

        border_size = 2,

        col = {
            active_border   = { colors = {theme.active_1, theme.active_2}, angle = 45 },
            inactive_border = theme.inactive,
        },

        -- Set to true to enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = false,

        -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
        allow_tearing = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 10,
        rounding_power = 2,

        -- Change transparency of focused and unfocused windows
        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 18,
            render_power = 3,
            color        = 0x66000000,
            color_inactive = 0x33000000,
        },

        blur = {
            enabled   = true,
            size      = 6,
            passes    = 2,
            vibrancy  = 0.2,
            new_optimizations = true,
        },
    },

    animations = {
        enabled = true,
    },
})

-- Animaciones (afinadas para 144 Hz): resortes suaves, workspaces con deslizamiento, borde con degradado giratorio.
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeOutExpo",    { type = "bezier", points = { {0.16, 1},    {0.3, 1}     } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("easeInQuad",     { type = "bezier", points = { {0.55, 0.085},{0.68, 0.53} } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

-- Resortes: casi críticamente amortiguados (rebote mínimo, sensación "viva")
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })
hl.curve("soft",           { type = "spring", mass = 1, stiffness = 260,      dampening = 22 })
hl.curve("glide",          { type = "spring", mass = 1, stiffness = 180,      dampening = 26 })

hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 6,    bezier = "easeOutQuint" })
hl.animation({ leaf = "borderangle",   enabled = true,  speed = 60,   bezier = "linear",       style = "loop" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.8,  spring = "soft" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.4,  spring = "soft",         style = "popin 90%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 2.6,  bezier = "easeInQuad",   style = "popin 92%" })
hl.animation({ leaf = "windowsMove",   enabled = true,  speed = 4.8,  spring = "soft" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 2.2,  bezier = "easeOutQuint" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.8,  bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "fadeSwitch",    enabled = true,  speed = 3,    bezier = "quick" })
hl.animation({ leaf = "fadeShadow",    enabled = true,  speed = 3,    bezier = "quick" })
hl.animation({ leaf = "fadeDim",       enabled = true,  speed = 3,    bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 4,    spring = "glide",        style = "slide" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 4,    spring = "glide",        style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 4,    spring = "glide",        style = "slide" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })

-- Ref https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- "Smart gaps" / "No gaps when only"
-- uncomment all if you wish to use that.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
    dwindle = {
        preserve_split = true, -- You probably want this
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
    master = {
        new_status = "master",
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for more
hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})

----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper = -1,    -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo   = false, -- If true disables the random hyprland logo / anime girl background. :(
        vrr                     = 2,     -- FreeSync/G-Sync solo en pantalla completa (0 = apagado, 1 = siempre)
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

-- Bloquear pantalla (SDDM solo hace el login; el bloqueo lo hace hyprlock, con el mismo estilo)
hl.bind("SUPER + L", hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/lock.sh"))

-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
local closeWindowBind = hl.bind(mainMod .. " + C", hl.dsp.window.close())
-- closeWindowBind:set_enabled(false)
hl.bind("ALT + F4", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
-- Tecla Win sola (toque, al soltar): abre/cierra el dashboard. No se dispara con Win+otra tecla.
hl.bind("SUPER + SUPER_L", hl.dsp.exec_cmd(qs .. " ipc call dashboard toggle"), { release = true })
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(qs .. " ipc call dashboard toggle"))
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd(qs .. " ipc call settings toggle"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(qs .. " ipc call widgets edit"))
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.exec_cmd(qs .. " ipc call gamemode toggle"))
hl.bind(mainMod .. " + ESCAPE", hl.dsp.exec_cmd(qs .. " ipc call session toggle"))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))    -- dwindle only
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Move active window to the monitor on the left/right (and follow it)
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ monitor = "l", follow = true }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ monitor = "r", follow = true }))

-- Resize active window with mainMod + CTRL + arrow keys (hold to repeat)
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.window.resize({ x = -40, y = 0,   relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.resize({ x = 40,  y = 0,   relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + up",    hl.dsp.window.resize({ x = 0,   y = -40, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + down",  hl.dsp.window.resize({ x = 0,   y = 40,  relative = true }), { repeating = true })

-- Move window within the layout (swap) with mainMod + ALT + arrow keys
hl.bind(mainMod .. " + ALT + left",  hl.dsp.window.swap({ direction = "left" }))
hl.bind(mainMod .. " + ALT + right", hl.dsp.window.swap({ direction = "right" }))
hl.bind(mainMod .. " + ALT + up",    hl.dsp.window.swap({ direction = "up" }))
hl.bind(mainMod .. " + ALT + down",  hl.dsp.window.swap({ direction = "down" }))

-- Virtual desktop groups: group g = workspace g on the main monitor + workspace g+10 on the side one.
-- Los nombres salen de monitors.lua (main/side). Si el secundario no existe, los grupos usan solo el principal.
local function mon_exists(name)
    if not name then return false end
    local ok, m = pcall(hl.get_monitor, name)
    return ok and m ~= nil
end
local MON_MAIN, MON_SIDE = MON.main, MON.side
local GROUPS = 3

for g = 1, GROUPS do
    if MON_MAIN then hl.workspace_rule({ workspace = tostring(g),      monitor = MON_MAIN, persistent = true, default = (g == 1) }) end
    if MON_SIDE then hl.workspace_rule({ workspace = tostring(g + 10), monitor = MON_SIDE, persistent = true, default = (g == 1) }) end
end

local function clamp_group(g) return math.max(1, math.min(GROUPS, g)) end

local function current_group()
    local mon = mon_exists(MON_MAIN) and hl.get_monitor(MON_MAIN) or hl.get_active_monitor()
    local ws = mon and mon.active_workspace
    local id = ws and ws.id or 1
    if id > 10 then id = id - 10 end
    return clamp_group(id)
end

local function has_side() return mon_exists(MON_SIDE) and mon_exists(MON_MAIN) end

-- Show group g on both monitors, keeping focus on the monitor you were on
local function goto_group(g)
    g = clamp_group(g)
    if not has_side() then hl.dispatch(hl.dsp.focus({ workspace = g })); return end
    local origin = hl.get_active_monitor()
    hl.dispatch(hl.dsp.focus({ workspace = g + 10 }))
    hl.dispatch(hl.dsp.focus({ workspace = g }))
    if origin and origin.name == MON_SIDE then
        hl.dispatch(hl.dsp.focus({ monitor = MON_SIDE }))
    end
end

-- Send the active window to group g (same monitor) and follow it
local function window_to_group(g)
    g = clamp_group(g)
    local win = hl.get_active_window()
    if not win then return end
    local ws = (has_side() and win.monitor and win.monitor.name == MON_SIDE) and (g + 10) or g
    hl.dispatch(hl.dsp.window.move({ workspace = ws, follow = false }))
    goto_group(g)
    hl.dispatch(hl.dsp.focus({ window = win }))
end

-- Ctrl+Alt+Left/Right: previous/next group.  Ctrl+Alt+Shift+Left/Right: move window there and follow
hl.bind("CTRL + ALT + left",          function() goto_group(current_group() - 1) end)
hl.bind("CTRL + ALT + right",         function() goto_group(current_group() + 1) end)
hl.bind("CTRL + ALT + SHIFT + left",  function() window_to_group(current_group() - 1) end)
hl.bind("CTRL + ALT + SHIFT + right", function() window_to_group(current_group() + 1) end)

-- mainMod + [1-9]: jump to group, mainMod + SHIFT + [1-9]: move window to that group
for g = 1, GROUPS do
    hl.bind(mainMod .. " + " .. g,         function() goto_group(g) end)
    hl.bind(mainMod .. " + SHIFT + " .. g, function() window_to_group(g) end)
end

-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Example window rules that are useful

local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

hl.window_rule({
    name  = "spotify-background",
    match = { class = "^[Ss]potify$" },

    workspace = "special:spotify silent",
})

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

