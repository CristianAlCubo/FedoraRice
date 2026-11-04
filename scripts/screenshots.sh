#!/usr/bin/env bash
# Saca las capturas de los paneles del rice en el monitor ENFOCADO.
# Úsalo en un workspace VACÍO (para no fotografiar tu trabajo) y revisa las imágenes antes de subirlas.
set -euo pipefail
OUT="$(cd "$(dirname "$0")/.." && pwd)/screenshots"; mkdir -p "$OUT"
MON=$(hyprctl monitors -j | python3 -c "import json,sys;print(next(m['name'] for m in json.load(sys.stdin) if m['focused']))")
Q=(qs -p "$HOME/.config/quickshell/bar" ipc call)
shot() { sleep 2; grim -o "$MON" "$OUT/$1.png"; }
"${Q[@]}" dashboard toggle; shot dashboard; "${Q[@]}" dashboard hide; sleep 1
"${Q[@]}" controls toggle;  shot controls;  "${Q[@]}" controls hide;  sleep 1
"${Q[@]}" launcher toggle;  shot launcher;  "${Q[@]}" launcher toggle; sleep 1
"${Q[@]}" session toggle;   shot session;   "${Q[@]}" session close
echo "Listo en $OUT (monitor $MON). Revísalas y conviértelas a .jpg si pesan mucho."
