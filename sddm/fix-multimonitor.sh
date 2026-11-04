#!/bin/sh
# El greeter de SDDM (Weston kiosk) se apilaba mal con dos monitores: DP-2 quedaba negro.
# Solución: en el login solo se usa el monitor principal (DP-2); DP-1 se apaga hasta entrar a Hyprland.
# Ejecutar con sudo.
set -e
install -d /etc/sddm
cat > /etc/sddm/weston.ini <<'EOS'
[output]
name=DP-1
mode=off
EOS
chmod 644 /etc/sddm/weston.ini
install -d /etc/sddm.conf.d
cat > /etc/sddm.conf.d/20-weston.conf <<'EOS'
[Wayland]
CompositorCommand=/usr/bin/weston --shell=kiosk --config=/etc/sddm/weston.ini
EOS
echo "Listo. Se aplica en el próximo inicio de SDDM (reinicio o cierre de sesión)."
