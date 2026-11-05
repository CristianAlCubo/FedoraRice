#!/bin/sh
# Compone un fondo de bloqueo.
#   lockbg.sh ORIGEN SALIDA ANCHO ALTO panel|plain [desplazamiento-%]
#   panel: arte nítido + panel izquierdo (30 %) difuminado y oscurecido (monitor principal).
#   plain: la imagen entera recortada a la pantalla (resto de monitores).
#   El desplazamiento empuja el arte a la derecha para que el panel no tape al motivo.
set -e
SRC="$1"; OUT="$2"; W="$3"; H="$4"; KIND="${5:-plain}"; SHIFT="${6:-0}"
[ -f "$SRC" ] || { echo "lockbg: no existe $SRC" >&2; exit 1; }
command -v magick >/dev/null || { echo "lockbg: falta ImageMagick (magick)" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
if [ "$KIND" = panel ]; then
  P=$(( W * 30 / 100 ))
  magick "$SRC" -resize "${W}x${H}^" -gravity center -extent "${W}x${H}" +repage -roll "+$(( W * SHIFT / 100 ))+0" "$TMP/base.png"
  magick -size "${W}x${H}" xc:black -fill white -draw "rectangle 0,0 $P,$H" "$TMP/mask.png"
  magick "$TMP/base.png" \
    \( "$TMP/base.png" -blur 0x38 -modulate 42,75,100 \) "$TMP/mask.png" -composite \
    -fill "rgba(255,255,255,0.10)" -draw "rectangle $P,0 $((P+1)),$H" \
    "$TMP/out.png"
else
  magick "$SRC" -resize "${W}x${H}^" -gravity center -extent "${W}x${H}" +repage "$TMP/out.png"
fi
mv "$TMP/out.png" "$OUT"
