#!/usr/bin/env bash
# Copia tu configuración VIVA (~/.config, ~/.zshrc…) a este repo, sin secretos ni respaldos.
# Las rutas /home/<usuario> se guardan como @HOME@ y install.sh las reescribe.
set -euo pipefail
R="$(cd "$(dirname "$0")" && pwd)"; C="$HOME/.config"
EXC=(--exclude='*.bak*' --exclude='*.pre-*' --exclude='*.v[0-9]' --exclude='*.latest' --exclude='__pycache__'
     --exclude='spotify-api.json' --exclude='wallpaper.state' --exclude='widgets.json' --exclude='avatar.png' --exclude='hyprpaper.conf')
mkdir -p "$R/config"
for d in quickshell hypr rice kitty zsh fastfetch git; do
  [ -d "$C/$d" ] && rsync -a --delete "${EXC[@]}" --exclude='ignore' "$C/$d/" "$R/config/$d/"
done
[ -f "$C/starship.toml" ] && cp "$C/starship.toml" "$R/config/starship.toml"
[ -f "$HOME/.local/src/sddm-cubi/Main.qml" ] && rsync -a --delete --exclude='*.bak*' "$HOME/.local/src/sddm-cubi/" "$R/sddm/"
# Plantilla del asistente: misma estructura, sin claves
[ -f "$C/nexora/env" ] && { mkdir -p "$R/config/nexora"; sed -E 's/^([A-Z_]*(KEY|TOKEN|SECRET)[A-Z_]*)=.*/\1=/' "$C/nexora/env" > "$R/config/nexora/env.example"; }
# Rutas personales -> @HOME@ (solo archivos de texto)
{ grep -rIl "$HOME" "$R/config" "$R/sddm" 2>/dev/null || true; } | xargs -r sed -i "s#$HOME#@HOME@#g"
echo "Sincronizado. Revisa con: git -C $R status"
