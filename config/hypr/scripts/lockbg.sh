#!/bin/sh
# Genera los fondos del bloqueo.
#   Monitor principal (2560x1440): arte nítido + panel izquierdo difuminado y oscurecido.
#   Monitor secundario (1920x1080): la imagen entera, sin panel.
# Uso: lockbg.sh [nombre-del-wallpaper] [desplazamiento-%]
#   El desplazamiento empuja el arte a la derecha en el monitor principal, para que el panel
#   no tape al personaje (ej. o367kp 22). Por defecto: o367kp con 22.
NAME="${1:-o367kp}"
SHIFT="${2:-22}"
DIR="$HOME/Imágenes/Wallpapers"
OUT="$HOME/.cache/hyprlock"; mkdir -p "$OUT"
[ -f "$DIR/$NAME-1440p.png" ] || { echo "no existe $DIR/$NAME-1440p.png" >&2; exit 1; }

# Principal: con panel
W=2560; H=1440; P=$(( W * 30 / 100 ))
magick "$DIR/$NAME-1440p.png" -resize "${W}x${H}^" -gravity center -extent "${W}x${H}" +repage -roll "+$(( W * SHIFT / 100 ))+0" "$OUT/.base.png"
magick -size "${W}x${H}" xc:black -fill white -draw "rectangle 0,0 $P,$H" "$OUT/.mask.png"
magick "$OUT/.base.png" \
  \( "$OUT/.base.png" -blur 0x38 -modulate 42,75,100 \) "$OUT/.mask.png" -composite \
  -fill "rgba(255,255,255,0.10)" -draw "rectangle $P,0 $((P+1)),$H" \
  "$OUT/lock-2560x1440.png"
rm -f "$OUT/.base.png" "$OUT/.mask.png"

# Secundario: imagen entera
SRC2="$DIR/$NAME-1080p.png"; [ -f "$SRC2" ] || SRC2="$DIR/$NAME-1440p.png"
magick "$SRC2" -resize "1920x1080^" -gravity center -extent "1920x1080" +repage "$OUT/lock-1920x1080.png"
echo "listo: $NAME"
