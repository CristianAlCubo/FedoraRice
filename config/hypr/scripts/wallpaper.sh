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
IMGS="$HOME/Imágenes/Wallpapers"
VIDS="$HOME/Videos/Wallpapers"
CACHE="$HOME/.cache/cubi"
HYPR="$HOME/.config/hypr"
STATE="$HYPR/wallpaper.state"
SDDM_BG="/usr/share/sddm/themes/cubi/background.jpg"
export PATH="$HOME/.local/bin:$PATH"
mkdir -p "$CACHE/thumbs"

[ -f "$STATE" ] || cat > "$STATE" <<'EOS'
DESKTOP_KIND=video
DESKTOP=city
LOCK=wy56lp
LOCK_SHIFT=0
LOGIN=2y7529
EOS
. "$STATE"

save() { grep -v "^$1=" "$STATE" > "$STATE.tmp"; echo "$1=$2" >> "$STATE.tmp"; mv "$STATE.tmp" "$STATE"; }
fail() { echo "ERR $*"; exit 1; }

apply_desktop() {
  pkill -x mpvpaper 2>/dev/null; pkill -x hyprpaper 2>/dev/null
  sleep 0.4
  if [ "$DESKTOP_KIND" = video ]; then
    OPTS="no-audio loop hwdec=auto-safe panscan=1.0"
    mpvpaper -f -p -a FULL -o "$OPTS" DP-2 "$VIDS/$DESKTOP-1440p.mp4"
    mpvpaper -f -p -a FULL -o "$OPTS" DP-1 "$VIDS/$DESKTOP-1080p.mp4"
  else
    cat > "$HYPR/hyprpaper.conf" <<EOC
# Generado por wallpaper.sh — no editar a mano (cámbialo desde Ajustes).
splash = false
ipc = true

wallpaper {
    monitor = DP-2
    path = $IMGS/$DESKTOP-1440p.png
    fit_mode = cover
}

wallpaper {
    monitor = DP-1
    path = $IMGS/$DESKTOP-1080p.png
    fit_mode = cover
}
EOC
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
    "$HYPR/scripts/lockbg.sh" "$name" "$shift_pct" >/dev/null || fail "no pude generar el fondo del bloqueo"
    save LOCK "$name"; save LOCK_SHIFT "$shift_pct"
    echo "OK bloqueo" ;;
  set-login)
    name="$2"
    [ -f "$IMGS/$name-1440p.png" ] || fail "no existe la imagen $name"
    [ -d /usr/share/sddm/themes/cubi ] || fail "el tema de SDDM no está instalado"
    magick "$IMGS/$name-1440p.png" -resize 2560x1440^ -gravity center -extent 2560x1440 \
      -blur 0x16 -modulate 52,85 -quality 90 "$CACHE/login-bg.jpg" || fail "no pude preparar la imagen"
    cp "$CACHE/login-bg.jpg" "$HOME/.local/src/sddm-cubi/background.jpg" 2>/dev/null
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
  *) echo "uso: wallpaper.sh apply|status|list|set-desktop|set-lock|set-login|import" ; exit 2 ;;
esac
