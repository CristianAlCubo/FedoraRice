#!/bin/sh
# Modo juego: sin animaciones, blur, sombras ni huecos (rendimiento). Restaurar = recargar la configuración.
#   gamemode.sh on | off | toggle | status
export HYPRLAND_INSTANCE_SIGNATURE="${HYPRLAND_INSTANCE_SIGNATURE:-$(ls -t /run/user/$(id -u)/hypr/ 2>/dev/null | head -1)}"
is_on() { hyprctl getoption animations:enabled 2>/dev/null | head -1 | grep -q 'false'; }
case "$1" in
  status) is_on && echo on || echo off ;;
  on)  hyprctl eval 'hl.config({ animations = { enabled = false }, decoration = { blur = { enabled = false }, shadow = { enabled = false } }, general = { gaps_in = 0, gaps_out = 0 } })' >/dev/null ;;
  off) hyprctl reload >/dev/null ;;
  toggle|"") if is_on; then "$0" off; else "$0" on; fi ;;
esac
