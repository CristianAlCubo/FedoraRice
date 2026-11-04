#!/bin/sh
# Bloquea la pantalla y pausa la multimedia, salvo Spotify (sigue sonando).
pidof hyprlock && exit 0
for p in $(playerctl -l 2>/dev/null | grep -vi '^spotify'); do
  playerctl -p "$p" pause 2>/dev/null
done
exec hyprlock
