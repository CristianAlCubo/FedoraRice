#!/bin/sh
# Instala el tema "cubi" de SDDM, lo selecciona y deja SDDM como gestor de inicio de sesión.
# Ejecutar con sudo. Es seguro repetirlo.
#   sh sddm/install.sh [usuario]
set -e
src="$(dirname "$(readlink -f "$0")")"
user="${1:-${SUDO_USER:-}}"

# 1. Tema (el fondo del login se conserva si ya lo cambiaste desde Ajustes → Fondos)
install -d /usr/share/sddm/themes/cubi
install -m 644 "$src/Main.qml" "$src/metadata.desktop" "$src/theme.conf" /usr/share/sddm/themes/cubi/
[ -f /usr/share/sddm/themes/cubi/background.jpg ] || install -m 644 "$src/background.jpg" /usr/share/sddm/themes/cubi/

# 2. Configuración: tema + greeter Wayland (weston en modo kiosco)
install -d /etc/sddm.conf.d
printf '[Theme]\nCurrent=cubi\n' > /etc/sddm.conf.d/10-cubi.conf

# Con varios monitores el greeter de weston se apila mal (una pantalla queda en negro):
# en el login solo se enciende el monitor de mayor resolución; el resto se apaga hasta entrar.
best=""; best_area=0; others=""
for d in /sys/class/drm/card*-*; do
  [ -f "$d/status" ] && [ "$(cat "$d/status")" = connected ] || continue
  name="${d##*/}"; name="${name#card*-}"
  mode="$(head -1 "$d/modes" 2>/dev/null)"
  w="$(echo "$mode" | sed 's/x.*//; s/[^0-9]//g')"; h="$(echo "$mode" | sed 's/^[^x]*x//; s/[^0-9]//g')"
  area=$(( ${w:-0} * ${h:-0} ))
  if [ "$area" -gt "$best_area" ]; then [ -n "$best" ] && others="$others $best"; best="$name"; best_area=$area
  else others="$others $name"; fi
done
install -d /etc/sddm
{ echo "# Generado por sddm/install.sh. Monitor del login: ${best:-desconocido}"
  for o in $others; do printf '[output]\nname=%s\nmode=off\n\n' "$o"; done; } > /etc/sddm/weston.ini
chmod 644 /etc/sddm/weston.ini
cat > /etc/sddm.conf.d/20-weston.conf <<'EOS'
[General]
DisplayServer=wayland

[Wayland]
CompositorCommand=weston --shell=kiosk --config=/etc/sddm/weston.ini
EOS

# 3. Sesión por defecto: Hyprland (solo si SDDM aún no recuerda otra)
if [ -f /usr/share/wayland-sessions/hyprland.desktop ]; then
  install -d -o sddm -g sddm /var/lib/sddm 2>/dev/null || install -d /var/lib/sddm
  st=/var/lib/sddm/state.conf
  if ! grep -q '^Session=' "$st" 2>/dev/null; then
    { echo "[Last]"; echo "Session=/usr/share/wayland-sessions/hyprland.desktop"; [ -n "$user" ] && echo "User=$user"; } > "$st"
    chown sddm:sddm "$st" 2>/dev/null || true
  fi
fi

# 4. SDDM como gestor de inicio de sesión (reemplaza a GDM/LightDM)
cur="$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || true)"
case "$cur" in
  */sddm.service) ;;
  *) for dm in gdm lightdm lxdm; do systemctl disable "$dm.service" 2>/dev/null || true; done
     systemctl enable --force sddm.service ;;
esac
systemctl set-default graphical.target >/dev/null 2>&1 || true
echo "SDDM listo (tema cubi). Se verá en el próximo reinicio."
