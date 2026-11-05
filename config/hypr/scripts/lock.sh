#!/bin/sh
# Bloquea la pantalla con hyprlock (pausa la multimedia, salvo Spotify).
#   lock.sh            prepara los fondos para los monitores conectados y bloquea
#   lock.sh --prepare  solo prepara (lo usan install.sh y Ajustes → Fondos); no bloquea
# Nunca deja la pantalla en negro: si no hay imagen o falla ImageMagick, el fondo es una
# captura difuminada de la propia pantalla.
STATE="$HOME/.config/hypr/wallpaper.state"
IMGS="$HOME/Imágenes/Wallpapers"
OUT="$HOME/.cache/hyprlock"
SCRIPTS="$HOME/.config/hypr/scripts"
mkdir -p "$OUT"

[ "$1" != --prepare ] && pidof hyprlock >/dev/null && exit 0

LOCK=""; LOCK_SHIFT=0
[ -f "$STATE" ] && . "$STATE"
SRC=""
for n in "$LOCK" a-mountain-range-with-sn-2 2y7529; do
  [ -n "$n" ] && [ -f "$IMGS/$n-1440p.png" ] && { SRC="$IMGS/$n-1440p.png"; LOCK="$n"; break; }
done
[ -z "$SRC" ] && SRC="$(ls "$IMGS"/*-1440p.png 2>/dev/null | head -1)"

# Monitores: "nombre ancho alto enfocado" (tamaño lógico = píxeles / escala).
MONS=""
if command -v hyprctl >/dev/null && command -v jq >/dev/null; then
  MONS="$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.disabled != true) |
    "\(.name) \((.width / .scale) | floor) \((.height / .scale) | floor) \(.focused)"' 2>/dev/null)"
fi

# Monitor del panel: el principal de monitors.lua si está conectado; si no, el enfocado; si no, el primero.
MAIN_PREF="$(sed -n 's/^[[:space:]]*main[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$HOME/.config/hypr/monitors.lua" 2>/dev/null | head -1)"
MAIN=""; MW=2560; MH=1440
if [ -n "$MONS" ]; then
  line="$(echo "$MONS" | awk -v m="$MAIN_PREF" '$1==m' | head -1)"
  [ -z "$line" ] && line="$(echo "$MONS" | awk '$4=="true"' | head -1)"
  [ -z "$line" ] && line="$(echo "$MONS" | head -1)"
  MAIN="$(echo "$line" | cut -d' ' -f1)"; MW="$(echo "$line" | cut -d' ' -f2)"; MH="$(echo "$line" | cut -d' ' -f3)"
fi

bg() { # bg <monitor|""> <ancho> <alto> panel|plain → bloque background
  img=""
  if [ -n "$SRC" ]; then
    img="$OUT/lock-$LOCK-s$LOCK_SHIFT-$2x$3-$4.png"
    if [ ! -s "$img" ] || [ "$SRC" -nt "$img" ]; then
      "$SCRIPTS/lockbg.sh" "$SRC" "$img" "$2" "$3" "$4" "$LOCK_SHIFT" >/dev/null 2>&1 || img=""
    fi
  fi
  if [ -n "$img" ]; then
    printf 'background {\n    monitor = %s\n    path = %s\n}\n' "$1" "$img"
  else
    printf 'background {\n    monitor = %s\n    path = screenshot\n    color = rgba(11, 13, 18, 1.0)\n    blur_passes = 3\n    blur_size = 8\n    brightness = 0.6\n}\n' "$1"
  fi
}

PX=$(( -MW * 35 / 100 ))
{
  echo "# Generado por lock.sh — se reescribe en cada bloqueo."
  echo "\$main = $MAIN"
  echo "\$px  = $PX"
  echo "\$pxl = $(( PX - 90 ))"
  echo "\$pxr = $(( PX + 90 ))"
  if [ -n "$MONS" ]; then
    echo "$MONS" | while read -r name w h _; do
      if [ "$name" = "$MAIN" ]; then bg "$name" "$w" "$h" panel; else bg "$name" "$w" "$h" plain; fi
    done
  else
    bg "" "$MW" "$MH" panel   # sin Hyprland en marcha (instalación): un fondo para todos
  fi
} > "$OUT/monitors.conf.tmp" && mv "$OUT/monitors.conf.tmp" "$OUT/monitors.conf"

# Limpia fondos viejos de otros wallpapers/resoluciones (deja los de la última semana)
find "$OUT" -name 'lock-*.png' -mtime +7 -delete 2>/dev/null

[ "$1" = --prepare ] && exit 0

for p in $(playerctl -l 2>/dev/null | grep -vi '^spotify'); do
  playerctl -p "$p" pause 2>/dev/null
done
exec hyprlock
