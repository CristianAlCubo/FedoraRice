#!/usr/bin/env bash
# Instala el rice en este equipo (Fedora + Hyprland). Respalda lo existente en ~/.config-backup-<fecha>.
# Uso: ./install.sh [--packages]   (--packages instala dependencias con dnf; pide sudo)
set -euo pipefail
R="$(cd "$(dirname "$0")" && pwd)"; C="$HOME/.config"; B="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
[ "${1:-}" = "--packages" ] && sudo dnf install -y $(grep -vE '^\s*(#|$)' "$R/packages/fedora.txt")
put() { # put <origen> <destino>: respalda el destino y copia reescribiendo @HOME@
  mkdir -p "$(dirname "$2")"
  [ -e "$2" ] && { mkdir -p "$B"; cp -a "$2" "$B/$(echo "$2" | tr / _)"; }
  rm -rf "$2"; cp -a "$1" "$2"
  { grep -rIl "@HOME@" "$2" 2>/dev/null || true; } | xargs -r sed -i "s#@HOME@#$HOME#g"
}
for d in quickshell hypr rice kitty zsh fastfetch git; do put "$R/config/$d" "$C/$d"; done
put "$R/config/starship.toml" "$C/starship.toml"
put "$R/home/zshrc" "$HOME/.zshrc.rice"
# Secretos: solo plantillas; rellena tus claves
[ -f "$C/nexora/env" ] || { mkdir -p "$C/nexora"; cp "$R/config/nexora/env.example" "$C/nexora/env"; sed -i "s#@HOME@#$HOME#g" "$C/nexora/env"; }
[ -f "$C/hypr/spotify-api.json" ] || cp "$R/config/hypr/spotify-api.example.json" "$C/hypr/spotify-api.json"
# Fuentes y comando rice-theme
mkdir -p "$HOME/.local/share/fonts/rice" "$HOME/.local/bin"; cp -n "$R"/fonts/* "$HOME/.local/share/fonts/rice/" 2>/dev/null || true
fc-cache -f >/dev/null 2>&1 || true
ln -sf "$C/rice/apply.py" "$HOME/.local/bin/rice-theme"; chmod +x "$C/rice/apply.py"
# Regenerar colores derivados del tema activo (sin recargar)
python3 "$C/rice/apply.py" --no-reload 2>/dev/null || true
cat <<MSG

Listo. Pendiente a mano:
  • Tu ~/.zshrc NO se tocó. El del rice está en ~/.zshrc.rice: compáralo o cópialo (cp ~/.zshrc.rice ~/.zshrc).
  • Rellena claves en ~/.config/nexora/env y ~/.config/hypr/spotify-api.json si usas esas funciones.
  • Cursor/iconos: ver README (Bibata-Modern-Ice, Papirus-Dark). Starship: https://starship.rs
  • Respaldo de lo anterior: $B
Cierra sesión y entra en Hyprland, o ejecuta: hyprctl reload
MSG
