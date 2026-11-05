# FedoraRice

Escritorio **Fedora 44 + Hyprland 0.56 (configuración Lua) + Quickshell**, con un solo archivo de tema que lo
colorea todo: barra, paneles, terminal, prompt, bloqueo de pantalla y hasta el `fzf`.
Inspirado en [caelestia-dots/shell](https://github.com/caelestia-dots/shell) (curvas de animación y estructura de paneles).

![Escritorio](screenshots/desktop.jpg)

## Qué incluye

| Pieza | Descripción |
|---|---|
| **Quickshell** (`config/quickshell/bar`) | Barra lateral, dashboard, lanzador de apps, panel de controles, notificaciones agrupadas, toasts, menú de sesión, modo juego, widgets de escritorio y ajustes. Un marco "inset" de esquinas redondeadas rodea el escritorio. |
| **Hyprland** (`config/hypr`) | `hyprland.lua` con animaciones suaves a 144 Hz (sin rebote), espacios de trabajo por grupos entre monitores, blur y sombras, y `hyprlock`. |
| **Sistema de temas** (`config/rice`) | `theme.json` + `apply.py` (`rice-theme`): **15 temas** más uno que sale del fondo de pantalla. Un comando regenera kitty, Hyprland, hyprlock, Starship, fastfetch y fzf. |
| **Terminal** (`config/kitty`, `config/zsh`, `home/zshrc`) | kitty + zsh + oh-my-zsh, prompt [Starship](https://starship.rs), bienvenida con fastfetch, fzf, zoxide, eza, bat y delta. Arranque de zsh ≈ 0,09 s. |
| **SDDM** (`sddm/`) | Tema de inicio de sesión a juego. |

## Temas

![Temas](screenshots/themes.png)

```bash
rice-theme set catppuccin     # aplica un tema a todo el escritorio (Quickshell se recarga solo)
rice-theme gtk                # sincroniza Nautilus/GTK con el tema (a propósito NO es automático)
```
También desde el panel de controles o el lanzador (“Tema: …”). Los 15 temas están en `config/rice/themes/`.

## Terminal

![Terminal](screenshots/terminal.png)

Bienvenida con fastfetch (≈10 ms), prompt Starship con iconos y colores del tema, `Ctrl+R` con fzf, `z proyecto`
para saltar de carpeta, `ll` con eza, `man` en color con bat y diffs de git con delta. Todo es opcional:
cada integración solo se activa si el programa está instalado (`config/zsh/qol.zsh`).

- Apagar la bienvenida: `export RICE_WELCOME=0` · volver a mostrarla: `welcome`
- Volver al prompt de oh-my-zsh: `promptomz` · al de Starship: `promptstar`

## Atajos principales

| Atajo | Acción |
|---|---|
| `Super` (solo) o `Super+D` | Dashboard |
| `Super+R` | Lanzador de apps (también comandos, temas y acciones) |
| `Super+I` | Ajustes (fondos, widgets…) |
| `Super+W` | Editar widgets de escritorio |
| `Super+Shift+G` | Modo juego |
| `Super+Esc` | Menú de sesión |
| `Super+L` | Bloquear |
| `Super+Q` / `Super+E` | Terminal / archivos |
| `Ctrl+Alt+←/→` | Cambiar de grupo de espacios de trabajo (en ambos monitores) |
| `Ctrl+Alt+Shift+←/→` | Mover la ventana a otro grupo |

(El resto está en `config/hypr/hyprland.lua`.)

## Instalación

Pensado para **Fedora 44** (Workstation u otra edición). Hyprland debe ser **≥ 0.55** (la configuración usa la API Lua).

```bash
git clone https://github.com/CristianAlCubo/FedoraRice.git
cd FedoraRice
./install.sh
```

Un solo comando instala las dependencias, aplica la configuración y deja SDDM listo: reinicia y entra en **Hyprland**.
Pide la contraseña de sudo una vez. **Es idempotente**: puedes repetirlo cuando quieras, también sobre una instalación
rota; cada paso comprueba el estado real y repara solo lo que falte.

```bash
./install.sh --check     # diagnóstico: ✔/✘ por componente, sin tocar nada
```

| Fase | Qué hace |
|---|---|
| 0. Previas | Comprueba Fedora, sudo y red. Registro en `~/.cache/rice-install.log`. |
| 1. Repos | Activa los COPR `byte0/hyprland` (Hyprland, hyprlock, hyprpaper) y `errornointernet/quickshell`. Cambiables con `HYPR_COPR=… QS_COPR=… ./install.sh`. |
| 2. Paquetes | `packages/fedora.txt`: los de `[core]` son obligatorios (si uno falla, se detiene y dice cuál); los de `[extra]` se intentan y se avisa. Verifica Hyprland ≥ 0.55 y lo actualiza si hace falta. |
| 3. Shell | zsh por defecto; oh-my-zsh + `zsh-autosuggestions` + `zsh-syntax-highlighting` (si una carpeta quedó a medias, se aparta y se reinstala); Starship. |
| 4. Fuentes y cursor | Rubik, FiraCode Nerd Font Mono, cursor Bibata, Papirus, GTK oscuro. |
| 5. Configuración | Copia `config/` a `~/.config` con rsync (solo lo que cambió; respaldo en `~/.config-backup/rice-<fecha>/`, se guardan los 5 últimos). **Nunca pisa tu estado**: `monitors.lua`, `wallpaper.state`, avatar, widgets, tema elegido, claves. |
| 6. Generados | Colores del tema, fondos, avatar por defecto y fondos del bloqueo. |
| 7. SDDM | Tema `cubi`, greeter Wayland (weston) solo en el monitor más grande, Hyprland como sesión por defecto, y SDDM como gestor de login (sustituye a GDM). Omitir con `--no-sddm`. |
| 8. Comprobación | Igual que `--check`. Si lo ejecutas dentro de Hyprland, además recarga Hyprland y Quickshell. |

Otras opciones: `--user-only` (sin sudo: solo la parte de usuario), `--keep-zshrc` (deja tu `~/.zshrc`; el del rice queda en `~/.zshrc.rice`).

**Monitores:** `~/.config/hypr/monitors.lua` describe los tuyos (se crea una vez desde `templates/monitors.lua` y nunca
se pisa). Nombres con `hyprctl monitors`. Una regla comodín enciende cualquier pantalla no descrita, el fondo se aplica a
todos los monitores conectados y el bloqueo detecta los monitores cada vez: si falta la imagen usa una captura difuminada,
así que nunca queda en negro.

**Opcional:** `~/.config/hypr/spotify-api.json` (búsqueda en Spotify desde el lanzador). Spotify, Steam, etc. se usan si están instalados.

## Mantener el repo al día

```bash
./sync.sh     # copia tu configuración viva al repo (sin secretos ni respaldos; rutas → @HOME@)
git add -A && git commit -m "…" && git push
```
`.gitignore` y `sync.sh` excluyen claves, estado local (`wallpaper.state`, `widgets.json`, `monitors.lua`), el avatar y los `*.bak*`. Los fondos de `wallpapers/` se añaden a mano.

## Paneles (capturas)

Para generar las capturas de dashboard, controles, lanzador y sesión: abre un workspace vacío y ejecuta
`scripts/screenshots.sh`.

## Créditos

[caelestia-dots/shell](https://github.com/caelestia-dots/shell) por la inspiración de animaciones y paneles ·
paletas de [Catppuccin](https://catppuccin.com), [Gruvbox](https://github.com/morhetz/gruvbox), [Nord](https://nordtheme.com),
[Dracula](https://draculatheme.com), [Rosé Pine](https://rosepinetheme.com), [Tokyo Night](https://github.com/folke/tokyonight.nvim)
y otras · [Starship](https://starship.rs) · [fastfetch](https://github.com/fastfetch-cli/fastfetch).

Licencia: MIT.
