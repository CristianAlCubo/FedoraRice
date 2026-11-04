#!/bin/sh
# Instala el tema "cubi" y lo selecciona en SDDM. Ejecutar con sudo.
set -e
src="$(dirname "$(readlink -f "$0")")"
install -d /usr/share/sddm/themes/cubi
cp -r "$src"/Main.qml "$src"/metadata.desktop "$src"/theme.conf "$src"/background.jpg /usr/share/sddm/themes/cubi/
install -d /etc/sddm.conf.d
printf '[Theme]\nCurrent=cubi\n' > /etc/sddm.conf.d/10-cubi.conf
echo "Tema instalado. Para activarlo: sudo systemctl disable gdm && sudo systemctl enable sddm  (y reinicia)"
