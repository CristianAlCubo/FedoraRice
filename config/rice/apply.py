#!/usr/bin/env python3
"""Genera los archivos de tema de kitty, Hyprland y hyprlock (y GTK solo con `gtk`) desde ~/.config/rice/theme.json.
Quickshell no lo necesita: Theme.qml lee el JSON directamente y se recarga solo."""
import json, os, subprocess, sys
H = os.path.expanduser("~")
TJ = f"{H}/.config/rice/theme.json"
t = json.load(open(TJ))
if len(sys.argv) > 2 and sys.argv[1] == "set":     # rice-theme set <id>: cambia colores, conserva fuentes/opacidad/layout
    if sys.argv[2] == "wallpaper":
        subprocess.run([sys.executable, f"{H}/.config/rice/wallpaper_theme.py"], check=False)
    p = f"{H}/.config/rice/themes/{sys.argv[2]}.json"
    if not os.path.exists(p): sys.exit(f"No existe el tema '{sys.argv[2]}'. Disponibles: " + ", ".join(sorted(f[:-5] for f in os.listdir(os.path.dirname(p)) if f.endswith('.json') and f != 'index.json')))
    pr = json.load(open(p))
    t.update(id=pr["id"], name=pr["name"], colors=pr["colors"], ansi=pr["ansi"])
    json.dump(t, open(TJ, "w"), indent=2, ensure_ascii=False)
c, op, fn = t["colors"], t["opacity"], t["fonts"]
ansi = t["ansi"]
hexs = lambda k: c[k].lstrip("#")
def rgba(k, a=1.0):
    h = hexs(k); return f"rgba({int(h[0:2],16)}, {int(h[2:4],16)}, {int(h[4:6],16)}, {a})"

# kitty
k = [f"# Generado por rice-theme desde theme.json ({t['name']}). No editar a mano.",
     f"font_family      {fn['mono']}", "bold_font        auto", "italic_font      auto", "bold_italic_font auto",
     f"font_size        {fn.get('monoSize', 12)}",
     f"background_opacity {op['terminal']}",
     f"foreground {c['text']}", f"background {c['base']}",
     f"selection_foreground {c['text']}", f"selection_background {c['selection']}",
     f"cursor {c['text']}", f"cursor_text_color {c['base']}", f"url_color {c['url']}",
     f"active_border_color {c['accent']}", f"inactive_border_color {c['line']}",
     f"tab_bar_background {c['bgDark']}", f"active_tab_background {c['accent']}", f"active_tab_foreground {c['ink']}",
     f"inactive_tab_background {c['surface']}", f"inactive_tab_foreground {c['dim']}",
     "tab_bar_style powerline",
     f"active_tab_foreground {c['bgDark']}", f"active_tab_background {c['accent']}",
     f"inactive_tab_foreground {c['dim']}", f"inactive_tab_background {c['line']}"]
k += [f"color{i} {v}" for i, v in enumerate(ansi)]
open(f"{H}/.config/kitty/theme.conf", "w").write("\n".join(k) + "\n")

# Hyprland (Lua)
open(f"{H}/.config/hypr/colors.lua", "w").write(
f'''-- Generado por rice-theme desde theme.json ({t['name']}). No editar a mano.
return {{
  active_1 = "rgba({hexs('accent')}ee)",
  active_2 = "rgba({hexs('accent2')}ee)",
  inactive = "rgba({hexs('line')}aa)",
}}
''')

# hyprlock
open(f"{H}/.config/hypr/colors.conf", "w").write(
f'''# Generado por rice-theme desde theme.json ({t['name']}). No editar a mano.
$mono   = {fn['lockMono']}
$sans   = {fn['sans']}
$text   = {rgba('text')}
$dim    = {rgba('dim')}
$faint  = {rgba('text', 0.07)}
$line   = {rgba('text', 0.11)}
$accent = {rgba('accent')}
''')

# GTK 3/4 + libadwaita (Archivos/Nautilus): SOLO bajo demanda → `rice-theme gtk` (botón "Sincronizar Archivos" del panel de controles).
# No se ejecuta al cambiar de tema y nunca reinicia ni abre Archivos.
if sys.argv[1:2] == ["gtk"]:
    def _mix(a, b, w):
        A = [int(c[a].lstrip("#")[i:i+2], 16) for i in (0, 2, 4)]
        B = [int(c[b].lstrip("#")[i:i+2], 16) for i in (0, 2, 4)]
        return "#" + "".join(f"{round(x + (y - x) * w):02x}" for x, y in zip(A, B))
    sf = t.get("surfaces", [0.09, 0.15, 0.22])
    s1, s2, s3 = _mix("base", "text", sf[0]), _mix("base", "text", sf[1]), _mix("base", "text", sf[2])
    gtk_colors = {
        "accent_bg_color": c["accent"], "accent_fg_color": c["ink"], "accent_color": c["accent"],
        "destructive_bg_color": c["red"], "destructive_fg_color": c["ink"], "destructive_color": c["red"],
        "success_bg_color": c["green"], "success_fg_color": c["ink"], "success_color": c["green"],
        "warning_bg_color": c["yellow"], "warning_fg_color": c["ink"], "warning_color": c["yellow"],
        "error_bg_color": c["red"], "error_fg_color": c["ink"], "error_color": c["red"],
        "window_bg_color": c["base"], "window_fg_color": c["text"],
        "view_bg_color": c["base"], "view_fg_color": c["text"],
        "headerbar_bg_color": c["bgDark"], "headerbar_fg_color": c["text"],
        "headerbar_border_color": c["line"], "headerbar_backdrop_color": c["base"],
        "headerbar_shade_color": "rgba(0,0,0,0.36)",
        "sidebar_bg_color": c["bgDark"], "sidebar_fg_color": c["text"],
        "sidebar_backdrop_color": c["bgDark"], "sidebar_shade_color": "rgba(0,0,0,0.36)",
        "secondary_sidebar_bg_color": c["base"], "secondary_sidebar_fg_color": c["text"],
        "card_bg_color": s2, "card_fg_color": c["text"], "card_shade_color": "rgba(0,0,0,0.36)",
        "dialog_bg_color": s1, "dialog_fg_color": c["text"],
        "popover_bg_color": s2, "popover_fg_color": c["text"], "popover_shade_color": "rgba(0,0,0,0.36)",
        "thumbnail_bg_color": s2, "thumbnail_fg_color": c["text"],
        "shade_color": "rgba(0,0,0,0.36)", "scrollbar_outline_color": "rgba(0,0,0,0.5)",
    }
    gtk4 = f"/* Generado por rice-theme desde theme.json ({t['name']}). No editar a mano. */\n" + \
           "".join(f"@define-color {k} {v};\n" for k, v in gtk_colors.items())
    gtk3 = gtk4 + "".join(f"@define-color {k} {v};\n" for k, v in {
        "theme_bg_color": c["base"], "theme_fg_color": c["text"],
        "theme_base_color": c["base"], "theme_text_color": c["text"],
        "theme_selected_bg_color": c["accent"], "theme_selected_fg_color": c["ink"],
        "theme_unfocused_bg_color": c["base"], "theme_unfocused_fg_color": c["text"],
        "theme_unfocused_base_color": c["base"], "theme_unfocused_text_color": c["text"],
        "theme_unfocused_selected_bg_color": c["selection"], "theme_unfocused_selected_fg_color": c["text"],
        "borders": c["line"], "unfocused_borders": c["line"],
        "insensitive_bg_color": s1, "insensitive_fg_color": c["dim"],
        "content_view_bg": c["base"], "link_color": c["url"], "visited_link_color": c["accent2"],
    }.items())
    for d, css in (("gtk-4.0", gtk4), ("gtk-3.0", gtk3)):
        os.makedirs(f"{H}/.config/{d}", exist_ok=True)
        open(f"{H}/.config/{d}/gtk.css", "w").write(css)
    subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", "prefer-dark"], stderr=subprocess.DEVNULL)
    print(f"Archivos/GTK sincronizado con el tema '{t['name']}'. Las ventanas ya abiertas lo aplican al reabrirlas.")
    sys.exit(0)

# Starship (prompt de zsh): paleta tomada del tema. Solo escribe un archivo; no toca la shell.
_ink = c["ink"]
starship = f"""# Generado por rice-theme desde theme.json ({t['name']}). No editar a mano.
"$schema" = 'https://starship.rs/config-schema.json'
palette = "rice"
add_newline = true
command_timeout = 800

# Marco estilo terminal "hacker": ╭─ segmentos ───────── hora ─╮ / ╰─❯
format = \"\"\"
[╭─](fg:line)$os$username$hostname$directory$git_branch$git_status$nodejs$python$golang$rust$docker_context$cmd_duration$fill$status$time[─╮](fg:line)
[╰─](fg:line)$sudo$character\"\"\"

[palettes.rice]
base = "{c['base']}"
text = "{c['text']}"
dim = "{c['dim']}"
line = "{c['line']}"
accent = "{c['accent']}"
accent2 = "{c['accent2']}"
cyan = "{c['cyan']}"
green = "{c['green']}"
yellow = "{c['yellow']}"
orange = "{c['orange']}"
red = "{c['red']}"
ink = "{c['ink']}"

[fill]
symbol = "─"
style = "fg:line"

[os]
disabled = false
format = "[](fg:accent)[$symbol ](bg:accent fg:ink)[](fg:accent) "
[os.symbols]
Fedora = ""
Linux = ""

[username]
show_always = true
format = "[](fg:accent2)[ $user](bg:accent2 fg:ink bold)"

[hostname]
ssh_only = false
format = "[@$hostname ](bg:accent2 fg:ink bold)[](fg:accent2) "

[directory]
format = "[](fg:cyan)[ $path]($style)[$read_only]($read_only_style)[](fg:cyan)"
style = "bg:cyan fg:ink bold"
read_only = " "
read_only_style = "bg:cyan fg:red bold"
truncation_length = 3
truncation_symbol = "…/"
[directory.substitutions]
"Documents" = " Documents"
"Downloads" = " Downloads"
"Pictures" = " Pictures"
"code" = " code"
".config" = " .config"

[git_branch]
symbol = ""
format = " [](fg:green)[$symbol $branch](bg:green fg:ink bold)[](fg:green)"

[git_status]
format = "[( $all_status$ahead_behind)]($style)"
style = "fg:yellow bold"
conflicted = ""
ahead = "⇡"
behind = "⇣"
diverged = "⇕"
untracked = "?"
stashed = ""
modified = "!"
staged = "+"
renamed = "»"
deleted = "✘"

[nodejs]
symbol = ""
format = " [$symbol $version](fg:green)"
[python]
symbol = ""
format = " [$symbol $version( \\\\\\\\($virtualenv\\\\\\\\))](fg:yellow)"
[golang]
symbol = ""
format = " [$symbol $version](fg:cyan)"
[rust]
symbol = ""
format = " [$symbol $version](fg:orange)"
[docker_context]
symbol = ""
format = " [$symbol $context](fg:cyan)"

[cmd_duration]
min_time = 2000
format = " [ $duration](fg:yellow)"

[status]
disabled = false
format = "[  $status ](fg:red bold)"

[time]
disabled = false
time_format = "%H:%M:%S"
format = "[ $time](fg:accent2)"

[sudo]
disabled = false
format = "[ ](fg:yellow bold)"

[character]
success_symbol = "[❯](fg:green bold)[❯](fg:accent bold)[❯](fg:accent2 bold)"
error_symbol = "[❯❯❯](fg:red bold)"
"""
os.makedirs(f"{H}/.config", exist_ok=True)
open(f"{H}/.config/starship.toml", "w", encoding="utf-8").write(starship)

# fastfetch (mensaje de bienvenida de la terminal): colores del tema. Solo escribe un archivo.
def _fc(k):
    h = c[k].lstrip("#"); return f"38;2;{int(h[0:2],16)};{int(h[2:4],16)};{int(h[4:6],16)}"
_ff = {
    "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
    "logo": {"type": "none", "padding": {"left": 1}},
    "display": {"separator": "  ", "key": {"width": 12},
                "color": {"keys": _fc("accent"), "title": _fc("accent2"), "separator": _fc("line"), "output": _fc("text")}},
    "modules": [
        {"type": "title", "format": "\uf30a {user-name}@{host-name}"},
        {"type": "separator", "string": "\u2500", "outputColor": _fc("line")},
        {"type": "os", "key": "\uf30a OS"},
        {"type": "kernel", "key": "\uf17c Kernel"},
        {"type": "uptime", "key": "\uf251 Uptime"},
        {"type": "shell", "key": "\uf120 Shell"},
        {"type": "wm", "key": "\uf2d0 WM"},
        {"type": "cpu", "key": "\uf2db CPU", "showPeCoreCount": False},
        {"type": "gpu", "key": "\uf108 GPU", "hideType": "integrated"},
        {"type": "memory", "key": "\U000f035b RAM"},
        {"type": "disk", "key": "\uf0a0 Disco", "folders": "/"},
        {"type": "custom", "key": "\U000f03d8 Tema", "format": t["name"]},
        {"type": "break"},
        {"type": "colors", "symbol": "circle", "paddingLeft": 1},
    ],
}
os.makedirs(f"{H}/.config/fastfetch", exist_ok=True)
json.dump(_ff, open(f"{H}/.config/fastfetch/config.jsonc", "w", encoding="utf-8"), indent=2, ensure_ascii=False)

# fzf: colores del tema (se carga desde ~/.config/zsh/qol.zsh solo si fzf está instalado)
os.makedirs(f"{H}/.config/zsh", exist_ok=True)
def _mix(a, b, w):
    A = [int(c[a].lstrip("#")[i:i+2], 16) for i in (0, 2, 4)]
    B = [int(c[b].lstrip("#")[i:i+2], 16) for i in (0, 2, 4)]
    return "#" + "".join(f"{round(x + (y - x) * w):02x}" for x, y in zip(A, B))
_fz = ",".join([f"bg:-1", f"fg:{c['text']}", f"hl:{c['accent']}", f"fg+:{c['text']}", f"bg+:{_mix('base','text',0.12)}", f"hl+:{c['accent2']}",
                f"info:{c['dim']}", f"prompt:{c['accent']}", f"pointer:{c['accent2']}", f"marker:{c['green']}", f"spinner:{c['accent2']}",
                f"header:{c['dim']}", f"border:{c['line']}", f"gutter:-1"])
open(f"{H}/.config/zsh/fzf-theme.zsh", "w", encoding="utf-8").write(
    f"# Generado por rice-theme desde theme.json ({t['name']}). No editar a mano.\n"
    f"export FZF_DEFAULT_OPTS=\"--height=45% --layout=reverse --border=rounded --info=inline --prompt='\u276f ' --pointer='\u25b6' --marker='\u2713' --color={_fz}\"\n")

# Recargas
env = dict(os.environ)
sig = sorted(os.listdir("/run/user/1000/hypr"), key=lambda s: os.path.getmtime(f"/run/user/1000/hypr/{s}"))[-1:] if os.path.isdir("/run/user/1000/hypr") else []
if sig and "--no-reload" not in sys.argv:
    env["HYPRLAND_INSTANCE_SIGNATURE"] = sig[0]
    subprocess.run(["hyprctl", "reload"], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["pkill", "-USR1", "-x", "kitty"], stderr=subprocess.DEVNULL)
print(f"Tema '{t['name']}' aplicado: kitty, hyprland, hyprlock (Quickshell se recarga solo).")
