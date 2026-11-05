#!/bin/sh
# Gestor de fondos: escritorio (imagen o video), bloqueo (hyprlock) y login (SDDM).
# El estado vive en ~/.config/hypr/wallpaper.state. Lo usa el panel de Ajustes de Quickshell.
#
#   wallpaper.sh apply                        aplica el fondo del escritorio guardado (autostart)
#   wallpaper.sh status                       imprime el estado (CLAVE=valor)
#   wallpaper.sh list                         lista fondos: tipo|nombre|miniatura
#   wallpaper.sh set-desktop image|video N    cambia el fondo del escritorio
#   wallpaper.sh set-lock N [desplazamiento]  cambia el fondo del bloqueo
#   wallpaper.sh set-login N                  cambia el fondo del login (pide contraseña de administrador)
#   wallpaper.sh import ARCHIVO [nombre]      convierte una imagen a 1440p/1080p y la añade
#   wallpaper.sh repair                       crea/corrige el estado si apunta a fondos que no existen
IMGS="$HOME/Imágenes/Wallpapers"
VIDS="$HOME/Videos/Wallpapers"
CACHE="$HOME/.cache/cubi"
HYPR="$HOME/.config/hypr"
STATE="$HYPR/wallpaper.state"
SDDM_BG="/usr/share/sddm/themes/cubi/background.jpg"
export PATH="$HOME/.local/bin:$PATH"
mkdir -p "$CACHE/thumbs"

DEF_IMAGE=a-street-with-buildings-; DEF_LOCK=a-mountain-range-with-sn-2; DEF_LOGIN=2y7529
first_image() { ls "$IMGS"/*-1440p.png 2>/dev/null | head -1 | xargs -r basename | sed 's/-1440p\.png$//'; }
pick() { for n in "$@"; do [ -n "$n" ] && [ -f "$IMGS/$n-1440p.png" ] && { echo "$n"; return; }; done; first_image; }

# (import no crea el estado: así la primera instalación elige el fondo ya importado)
[ "$1" = import ] || [ -f "$STATE" ] || printf 'DESKTOP_KIND=image\nDESKTOP=%s\nLOCK=%s\nLOCK_SHIFT=0\nLOGIN=%s\n' \
  "$(pick $DEF_IMAGE 2y7529)" "$(pick $DEF_LOCK)" "$DEF_LOGIN" > "$STATE"
[ -f "$STATE" ] && . "$STATE"

save() { grep -v "^$1=" "$STATE" > "$STATE.tmp"; echo "$1=$2" >> "$STATE.tmp"; mv "$STATE.tmp" "$STATE"; }
fail() { echo "ERR $*"; exit 1; }

# Monitores conectados: "nombre alto" (sin Hyprland en marcha: vacío → regla para todos)
monitors() { hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.disabled != true) | "\(.name) \(.height)"' 2>/dev/null; }
res_for() { [ "$1" -ge 1440 ] 2>/dev/null && echo 1440p || echo 1080p; }

repair_state() { # si el fondo guardado ya no existe, vuelve a uno que sí
  if [ "$DESKTOP_KIND" = video ]; then
    { [ -f "$VIDS/$DESKTOP-1440p.mp4" ] && command -v mpvpaper >/dev/null; } || { DESKTOP_KIND=image; DESKTOP=""; }
  fi
  if [ "$DESKTOP_KIND" != video ]; then
    DESKTOP_KIND=image; DESKTOP="$(pick "$DESKTOP" $DEF_IMAGE 2y7529)"
  fi
  LOCK="$(pick "$LOCK" $DEF_LOCK)"; LOCK_SHIFT="${LOCK_SHIFT:-0}"; LOGIN="${LOGIN:-$DEF_LOGIN}"
  printf 'DESKTOP_KIND=%s\nDESKTOP=%s\nLOCK=%s\nLOCK_SHIFT=%s\nLOGIN=%s\n' \
    "$DESKTOP_KIND" "$DESKTOP" "$LOCK" "$LOCK_SHIFT" "$LOGIN" > "$STATE"
}

apply_desktop() {
  repair_state
  pkill -x mpvpaper 2>/dev/null; pkill -x hyprpaper 2>/dev/null
  sleep 0.4
  MONS="$(monitors)"
  if [ "$DESKTOP_KIND" = video ]; then
    OPTS="no-audio loop hwdec=auto-safe panscan=1.0"
    if [ -z "$MONS" ]; then
      setsid mpvpaper -f -p -o "$OPTS" '*' "$VIDS/$DESKTOP-1440p.mp4" >/dev/null 2>&1 < /dev/null &
    else
      echo "$MONS" | while read -r name h; do
        f="$VIDS/$DESKTOP-$(res_for "$h").mp4"; [ -f "$f" ] || f="$VIDS/$DESKTOP-1440p.mp4"
        mpvpaper -f -p -o "$OPTS" "$name" "$f"
      done
    fi
  else
    {
      echo "# Generado por wallpaper.sh — no editar a mano (cámbialo desde Ajustes)."
      echo "splash = false"
      echo "ipc = true"
      if [ -z "$MONS" ]; then
        printf '\nwallpaper {\n    monitor =\n    path = %s\n    fit_mode = cover\n}\n' "$IMGS/$DESKTOP-1440p.png"
      else
        echo "$MONS" | while read -r name h; do
          f="$IMGS/$DESKTOP-$(res_for "$h").png"; [ -f "$f" ] || f="$IMGS/$DESKTOP-1440p.png"
          printf '\nwallpaper {\n    monitor = %s\n    path = %s\n    fit_mode = cover\n}\n' "$name" "$f"
        done
      fi
    } > "$HYPR/hyprpaper.conf"
    setsid hyprpaper >/dev/null 2>&1 < /dev/null &
  fi
}

case "$1" in
  apply) apply_desktop ;;
  status) cat "$STATE" ;;
  list)
    ls -t "$IMGS"/*-1440p.png 2>/dev/null | while read -r f; do
      n=$(basename "$f" -1440p.png); t="$CACHE/thumbs/$n.jpg"
      [ -f "$t" ] || magick "$f" -thumbnail 480x270^ -gravity center -extent 480x270 -quality 82 "$t"
      echo "image|$n|$t"
    done
    ls -t "$VIDS"/*-1440p.mp4 2>/dev/null | while read -r f; do
      n=$(basename "$f" -1440p.mp4); t="$CACHE/thumbs/v-$n.jpg"
      [ -f "$t" ] || ffmpeg -loglevel error -y -ss 2 -i "$f" -frames:v 1 \
        -vf "scale=480:270:force_original_aspect_ratio=increase,crop=480:270" "$t"
      echo "video|$n|$t"
    done ;;
  set-desktop)
    kind="$2"; name="$3"
    case "$kind" in
      image) [ -f "$IMGS/$name-1440p.png" ] || fail "no existe la imagen $name" ;;
      video) [ -f "$VIDS/$name-1440p.mp4" ] || fail "no existe el video $name" ;;
      *) fail "tipo inválido: $kind" ;;
    esac
    save DESKTOP_KIND "$kind"; save DESKTOP "$name"
    DESKTOP_KIND="$kind"; DESKTOP="$name"
    apply_desktop && echo "OK escritorio"
    # Tema "Fondo (auto)": regenerar los colores con el nuevo fondo
    grep -q '"id": "wallpaper"' "$HOME/.config/rice/theme.json" 2>/dev/null && \
      python3 "$HOME/.config/rice/apply.py" set wallpaper >/dev/null 2>&1 ;;
  set-lock)
    name="$2"; shift_pct="${3:-0}"
    [ -f "$IMGS/$name-1440p.png" ] || fail "no existe la imagen $name"
    save LOCK "$name"; save LOCK_SHIFT "$shift_pct"
    "$HYPR/scripts/lock.sh" --prepare >/dev/null 2>&1 || fail "no pude generar el fondo del bloqueo"
    echo "OK bloqueo" ;;
  set-login)
    name="$2"
    [ -f "$IMGS/$name-1440p.png" ] || fail "no existe la imagen $name"
    [ -d /usr/share/sddm/themes/cubi ] || fail "el tema de SDDM no está instalado"
    magick "$IMGS/$name-1440p.png" -resize 2560x1440^ -gravity center -extent 2560x1440 \
      -blur 0x16 -modulate 52,85 -quality 90 "$CACHE/login-bg.jpg" || fail "no pude preparar la imagen"
    pkexec install -m 644 "$CACHE/login-bg.jpg" "$SDDM_BG" || fail "login: cancelado o sin permisos"
    save LOGIN "$name"
    echo "OK login" ;;
  import)
    src="$2"; [ -f "$src" ] || fail "no existe $src"
    name="${3:-$(basename "${src%.*}" | tr 'A-Z' 'a-z' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//' | cut -c1-24)}"
    [ -n "$name" ] || name=fondo
    base="$name"; i=2
    while [ -f "$IMGS/$name-1440p.png" ]; do name="$base-$i"; i=$((i+1)); done
    mkdir -p "$IMGS/src"
    cp "$src" "$IMGS/src/imp-$name.${src##*.}"
    magick "$src" -filter Lanczos -resize 2560x1440^ -gravity center -extent 2560x1440 "$IMGS/$name-1440p.png" || fail "no pude convertir la imagen"
    magick "$src" -filter Lanczos -resize 1920x1080^ -gravity center -extent 1920x1080 "$IMGS/$name-1080p.png"
    echo "NAME $name" ;;
  repair) repair_state; echo "OK estado" ;;
  *) echo "uso: wallpaper.sh apply|status|list|set-desktop|set-lock|set-login|import|repair" ; exit 2 ;;
esac
