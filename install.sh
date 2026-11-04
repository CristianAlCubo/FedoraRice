#!/usr/bin/env bash
# Instala el rice completo en una Fedora (probado en 44) con Hyprland.
#   ./install.sh            todo lo de usuario, SIN sudo: configs, fuentes, fondos, oh-my-zsh + plugins,
#                           Starship, cursor Bibata, ajustes GTK. Respalda lo que reemplaza.
#   ./install.sh --system   además lo que pide sudo: COPR de Hyprland, paquetes dnf, zsh como shell, SDDM.
#   Opciones: --keep-zshrc  no reemplazar tu ~/.zshrc   |   --no-sddm  no instalar el tema de login
# Es seguro repetirlo. Los pasos que descargan de internet avisan y continúan si fallan.
set -uo pipefail
R="$(cd "$(dirname "$0")" && pwd)"; C="$HOME/.config"; B="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
SYSTEM=0; KEEPZ=0; SDDM=1
for a in "$@"; do case "$a" in --system|--packages) SYSTEM=1;; --keep-zshrc) KEEPZ=1;; --no-sddm) SDDM=0;; -h|--help) sed -n 2,8p "$0"; exit 0;; esac; done
say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m  ! %s\033[0m\n' "$*"; }
[ "$(id -u)" = 0 ] && { echo "No lo ejecutes como root: usa tu usuario (pedirá sudo solo con --system)."; exit 1; }

put() { # put <origen> <destino>: respalda el destino, copia y reescribe @HOME@
  mkdir -p "$(dirname "$2")"
  if [ -e "$2" ]; then mkdir -p "$B"; cp -a "$2" "$B/$(echo "$2" | tr / _)"; fi
  rm -rf "$2"; cp -a "$1" "$2"
  { grep -rIl "@HOME@" "$2" 2>/dev/null || true; } | xargs -r sed -i "s#@HOME@#$HOME#g"
}
dl() { curl -fsSL --retry 2 --connect-timeout 15 "$@"; }

# ── 1. Sistema (sudo) ────────────────────────────────────────────────────────
if [ $SYSTEM = 1 ]; then
  say "Paquetes del sistema (sudo)"
  command -v dnf >/dev/null || { warn "No hay dnf: ¿es Fedora?"; exit 1; }
  sudo dnf install -y dnf-plugins-core
  sudo dnf copr enable -y byte0/hyprland || warn "No pude habilitar el COPR byte0/hyprland (de ahí sale Hyprland)"
  sudo dnf install -y --skip-unavailable $(grep -vE '^\s*(#|$)' "$R/packages/fedora.txt") || warn "Algún paquete falló: revisa packages/fedora.txt"
  say "zsh como shell por defecto"
  [ "$(getent passwd "$USER" | cut -d: -f7)" = "$(command -v zsh)" ] || sudo usermod -s "$(command -v zsh)" "$USER" || warn "No pude cambiar el shell (hazlo con: chsh -s \$(which zsh))"
fi

# ── 2. Configuración (~/.config) ─────────────────────────────────────────────
say "Configuración"
for d in quickshell hypr rice kitty zsh fastfetch git; do put "$R/config/$d" "$C/$d"; done
put "$R/config/starship.toml" "$C/starship.toml"
# Estado y secretos: solo si no existen (nunca se pisan)
[ -f "$C/nexora/env" ] || { mkdir -p "$C/nexora"; cp "$R/config/nexora/env.example" "$C/nexora/env"; sed -i "s#@HOME@#$HOME#g" "$C/nexora/env"; chmod 600 "$C/nexora/env"; }
[ -f "$C/hypr/spotify-api.json" ] || { cp "$R/templates/spotify-api.json" "$C/hypr/spotify-api.json"; chmod 600 "$C/hypr/spotify-api.json"; }
[ -f "$C/hypr/wallpaper.state" ]  || cp "$R/templates/wallpaper.state" "$C/hypr/wallpaper.state"
chmod +x "$C"/hypr/scripts/* "$C/rice/apply.py" 2>/dev/null || true
mkdir -p "$HOME/.local/bin"; ln -sf "$C/rice/apply.py" "$HOME/.local/bin/rice-theme"
# ~/.zshrc
if [ $KEEPZ = 0 ]; then put "$R/home/zshrc" "$HOME/.zshrc"; else put "$R/home/zshrc" "$HOME/.zshrc.rice"; warn "~/.zshrc intacto; el del rice quedó en ~/.zshrc.rice"; fi

# ── 3. Fuentes ───────────────────────────────────────────────────────────────
say "Fuentes (Rubik, FiraCode Nerd Font Mono)"
mkdir -p "$HOME/.local/share/fonts/rice"; cp -n "$R"/fonts/* "$HOME/.local/share/fonts/rice/"; fc-cache -f >/dev/null 2>&1 || true

# ── 4. Fondos de pantalla ────────────────────────────────────────────────────
say "Fondos"
WALL="$HOME/Imágenes/Wallpapers"; [ -d "$HOME/Pictures" ] && [ ! -d "$HOME/Imágenes" ] && warn "Tu carpeta es ~/Pictures; el rice usa ~/Imágenes/Wallpapers (se crea)."
mkdir -p "$WALL"; cp -n "$R"/wallpapers/*-1440p.png "$R"/wallpapers/*-1080p.png "$WALL/" 2>/dev/null || true
if command -v magick >/dev/null && [ ! -f "$WALL/a-street-with-buildings--1440p.png" ]; then
  "$C/hypr/scripts/wallpaper.sh" import "$R/wallpapers/a-street-with-buildings-.png" a-street-with-buildings- >/dev/null 2>&1 || warn "No pude generar el fondo del escritorio (falta ImageMagick: dnf install ImageMagick)"
fi

# ── 5. oh-my-zsh, plugins y Starship ─────────────────────────────────────────
say "oh-my-zsh, plugins y Starship"
if command -v git >/dev/null; then
  [ -d "$HOME/.oh-my-zsh" ] || git clone -q --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh" || warn "No pude clonar oh-my-zsh"
  P="$HOME/.oh-my-zsh/custom/plugins"; mkdir -p "$P"
  [ -d "$P/zsh-autosuggestions" ]     || git clone -q --depth 1 https://github.com/zsh-users/zsh-autosuggestions "$P/zsh-autosuggestions" || warn "Falló zsh-autosuggestions"
  [ -d "$P/zsh-syntax-highlighting" ] || git clone -q --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting "$P/zsh-syntax-highlighting" || warn "Falló zsh-syntax-highlighting"
else warn "Falta git: instala git y repite."; fi
if ! command -v starship >/dev/null && [ ! -x "$HOME/.local/bin/starship" ]; then
  T="$(mktemp -d)"; if dl -o "$T/s.tgz" https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-musl.tar.gz && tar -xzf "$T/s.tgz" -C "$T" starship; then
    install -m755 "$T/starship" "$HOME/.local/bin/starship"; else warn "No pude instalar Starship (https://starship.rs)"; fi; rm -rf "$T"
fi

# ── 6. Cursor, iconos y ajustes GTK ──────────────────────────────────────────
say "Cursor Bibata, iconos Papirus y ajustes GTK"
I="$HOME/.local/share/icons"; mkdir -p "$I"
if [ ! -d "$I/Bibata-Modern-Ice" ] && [ ! -d /usr/share/icons/Bibata-Modern-Ice ]; then
  T="$(mktemp -d)"; dl -o "$T/b.tar.xz" https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Ice.tar.xz && tar -xf "$T/b.tar.xz" -C "$I" || warn "No pude instalar el cursor Bibata"; rm -rf "$T"
fi
if [ ! -d "$I/Papirus-Dark" ] && [ ! -d /usr/share/icons/Papirus-Dark ]; then
  warn "Papirus no está instalado: usa ./install.sh --system (paquete papirus-icon-theme) o https://github.com/PapirusDevelopmentTeam/papirus-icon-theme"
fi
mkdir -p "$HOME/.icons/default"; printf '[Icon Theme]\nName=Default\nInherits=Bibata-Modern-Ice\n' > "$HOME/.icons/default/index.theme"
for v in 3.0 4.0; do mkdir -p "$C/gtk-$v"; f="$C/gtk-$v/settings.ini"
  printf '[Settings]\ngtk-application-prefer-dark-theme=1\ngtk-cursor-theme-name=Bibata-Modern-Ice\ngtk-cursor-theme-size=24\ngtk-icon-theme-name=Papirus-Dark\n' > "$f"; done
if command -v gsettings >/dev/null; then
  gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
fi

# ── 7. Colores derivados del tema activo (sin recargar nada) ─────────────────
say "Aplicando tema"
python3 "$C/rice/apply.py" --no-reload 2>&1 | tail -1 || warn "No pude generar los colores (¿falta python3?)"

# ── 8. SDDM (sudo) ───────────────────────────────────────────────────────────
if [ $SYSTEM = 1 ] && [ $SDDM = 1 ] && [ -f "$R/sddm/install.sh" ]; then
  say "Tema de inicio de sesión (SDDM)"; sudo sh "$R/sddm/install.sh" || warn "Falló el tema de SDDM"
fi

say "Listo"
cat <<MSG
  Respaldo de lo reemplazado: ${B}   (si no existe, no había nada que respaldar)
  Pendiente a mano:
   • Monitores: config/hypr/hyprland.lua define DP-2 (2560x1440@144) y DP-1; ajusta los nombres con: hyprctl monitors
   • Claves (opcionales): ~/.config/nexora/env (asistente) y ~/.config/hypr/spotify-api.json (búsqueda de Spotify)
   • Spotify (snap), Steam, Docker, etc. son apps tuyas: el rice las usa si existen
   • Cierra sesión y entra en la sesión «Hyprland» (en SDDM/GDM), o abre una terminal nueva para ver zsh
MSG
[ $SYSTEM = 0 ] && echo "   • Falta lo de sudo (COPR de Hyprland, paquetes, zsh por defecto, SDDM): ./install.sh --system"
exit 0
