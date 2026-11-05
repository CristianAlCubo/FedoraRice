#!/usr/bin/env bash
# Instala el rice completo en Fedora (probado en 44): Hyprland + Quickshell + SDDM + zsh/Starship.
#
#   ./install.sh               instala y repara TODO (pide sudo para paquetes, zsh por defecto y SDDM)
#   ./install.sh --check       solo diagnostica: dice qué está bien y qué falta, sin tocar nada
#
#   Opciones:  --user-only    no usar sudo (solo configs, fuentes, oh-my-zsh, Starship…)
#              --no-sddm      no instalar ni activar el login SDDM
#              --keep-zshrc   no reemplazar tu ~/.zshrc (el del rice queda en ~/.zshrc.rice)
#
# Es idempotente: puedes repetirlo cuantas veces quieras, también sobre una instalación rota.
# Cada paso comprueba el estado REAL (no solo si existe una carpeta) y repara lo que falte.
# Nunca pisa tu estado: monitors.lua, wallpaper.state, avatar, widgets, tema elegido, claves.
# Lo que reemplaza queda en ~/.config-backup/rice-<fecha>/ (solo si algo cambió).
# Registro completo: ~/.cache/rice-install.log
set -uo pipefail

R="$(cd "$(dirname "$0")" && pwd)"
C="$HOME/.config"
# COPR candidatos, en orden. Solo se usan si el paquete NO está ya instalado; se activa el primero que
# tenga paquetes para tu versión de Fedora y traiga el paquete. Forzar uno: HYPR_COPR=usuario/repo ./install.sh
HYPR_COPRS="${HYPR_COPR:-ashbuk/Hyprland-Fedora lionheartp/Hyprland nett00n/hyprland solopasha/hyprland}"
QS_COPRS="${QS_COPR:-errornointernet/quickshell nett00n/hyprland}"
HYPR_MIN="0.55"                                     # primera versión con config en Lua
OS_RELEASE="${RICE_OS_RELEASE:-/etc/os-release}"
WALL="$HOME/Imágenes/Wallpapers"
BK="$HOME/.config-backup/rice-$(date +%Y%m%d-%H%M%S)"

MODE=install; SYSTEM=1; SDDM=1; KEEPZ=0
for a in "$@"; do
  case "$a" in
    --check) MODE=check ;;
    --user-only|--no-system) SYSTEM=0 ;;
    --system|--packages) SYSTEM=1 ;;          # compatibilidad: ahora es lo predeterminado
    --no-sddm) SDDM=0 ;;
    --keep-zshrc) KEEPZ=1 ;;
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Opción desconocida: $a (usa --help)"; exit 2 ;;
  esac
done

# ── Utilidades ───────────────────────────────────────────────────────────────
say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; WARNS+=("$*"); }
err()  { printf '  \033[31m✘\033[0m %s\n' "$*"; }
die()  { err "$*"; printf '\n\033[1;31mInstalación detenida.\033[0m Corrige lo anterior y vuelve a ejecutar ./install.sh (es seguro repetirlo).\n'; exit 1; }
has()  { command -v "$1" >/dev/null 2>&1; }
dl()   { curl -fsSL --retry 3 --connect-timeout 15 "$@"; }
ver_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }   # ver_ge A B: A ≥ B
hypr_version() { Hyprland --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1; }
login_shell() { getent passwd "$USER" 2>/dev/null | cut -d: -f7; }
starship_bin() { command -v starship 2>/dev/null || echo "$HOME/.local/bin/starship"; }
starship_ok() { local s; s="$(starship_bin)"; [ -x "$s" ] && "$s" --version >/dev/null 2>&1; }
omz_ok() { [ -r "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; }
pkg_section() { awk -v s="[$1]" '/^\[/{on=($0==s); next} on && !/^[[:space:]]*(#|$)/{print $1}' "$R/packages/fedora.txt"; }
pkg_missing() { local p; for p in "$@"; do rpm -q --whatprovides "$p" >/dev/null 2>&1 || echo "$p"; done; }
WARNS=()

[ "$(id -u)" = 0 ] && { echo "No lo ejecutes como root ni con sudo: usa tu usuario (el script pide sudo cuando lo necesita)."; exit 1; }

# ── Diagnóstico (fase final y modo --check) ──────────────────────────────────
check() {
  local bad=0 v
  c() { # c crit|opt "descripción" comando…
    local lvl="$1" d="$2"; shift 2
    if "$@" >/dev/null 2>&1; then ok "$d"
    elif [ "$lvl" = crit ]; then err "$d"; bad=$((bad + 1))
    else printf '  \033[33m!\033[0m %s\n' "$d"; fi
  }
  say "Comprobación"
  v="$(hypr_version)"
  c crit "Hyprland instalado"                                 has Hyprland
  c crit "Hyprland ≥ $HYPR_MIN (config en Lua) — tienes ${v:-ninguno}" ver_ge "${v:-0}" "$HYPR_MIN"
  c crit "hyprlock (bloqueo)"                                 has hyprlock
  c crit "hyprpaper (fondo)"                                  has hyprpaper
  c crit "Quickshell (barra, paneles, marco inset)"           has qs
  c crit "kitty"                                              has kitty
  c crit "ImageMagick y jq (fondos del bloqueo)"              sh -c 'command -v magick && command -v jq'
  c crit "zsh es tu shell por defecto"                        sh -c "[ \"\$(basename '$(login_shell)')\" = zsh ]"
  c crit "oh-my-zsh"                                          omz_ok
  c crit "plugin zsh-autosuggestions"                         test -r "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
  c crit "plugin zsh-syntax-highlighting"                     test -r "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  c crit "Starship (prompt)"                                  starship_ok
  c crit "~/.zshrc del rice"                                  sh -c "grep -q 'starship init zsh' '$HOME/.zshrc' || [ $KEEPZ = 1 ]"
  c crit "Config de Hyprland (hyprland.lua + monitors.lua + colores)" sh -c "[ -f '$C/hypr/hyprland.lua' ] && [ -f '$C/hypr/monitors.lua' ] && [ -f '$C/hypr/colors.lua' ]"
  c crit "Config de Quickshell"                               test -f "$C/quickshell/bar/shell.qml"
  c crit "Rutas @HOME@ resueltas"                             sh -c "! grep -rIqs '@HOME@' '$C/hypr' '$C/quickshell' '$C/rice' '$C/kitty'"
  c crit "Tema generado (kitty, hyprlock, Starship)"          sh -c "[ -f '$C/kitty/theme.conf' ] && [ -f '$C/hypr/colors.conf' ] && [ -f '$C/starship.toml' ]"
  c crit "Fondo del escritorio disponible"                    sh -c ". '$C/hypr/wallpaper.state' && { [ -f \"$WALL/\$DESKTOP-1440p.png\" ] || [ -f \"$HOME/Videos/Wallpapers/\$DESKTOP-1440p.mp4\" ]; }"
  c crit "Fondo del bloqueo preparado (nunca en negro)"       test -s "$HOME/.cache/hyprlock/monitors.conf"
  c crit "Fuentes (Rubik, FiraCode Nerd Font Mono)"           sh -c "fc-list | grep -qi 'FiraCode Nerd Font' && fc-list | grep -qi rubik"
  c opt  "Fuente Adwaita Mono (reloj del bloqueo)"            sh -c "fc-list | grep -qi 'Adwaita Mono'"
  c crit "Cursor Bibata"                                      sh -c "[ -f '$HOME/.local/share/icons/Bibata-Modern-Ice/index.theme' ] || [ -f /usr/share/icons/Bibata-Modern-Ice/index.theme ]"
  c crit "Iconos Papirus"                                     sh -c "[ -d /usr/share/icons/Papirus-Dark ] || [ -d '$HOME/.local/share/icons/Papirus-Dark' ]"
  c crit "hyprland-session.target (portales, tema oscuro GTK)" test -f "$C/systemd/user/hyprland-session.target"
  if [ $SDDM = 1 ] && [ $SYSTEM = 1 ]; then
    c crit "Tema de login SDDM (cubi)"                        test -f /usr/share/sddm/themes/cubi/Main.qml
    c crit "SDDM es el gestor de inicio de sesión"            sh -c "readlink -f /etc/systemd/system/display-manager.service | grep -q sddm"
  fi
  if has Hyprland && ver_ge "${v:-0}" "$HYPR_MIN"; then
    local out
    if out="$(timeout 30 Hyprland --verify-config --config "$C/hypr/hyprland.lua" 2>&1)"; then ok "hyprland.lua es válido (Hyprland --verify-config)"
    else printf '  \033[33m!\033[0m %s\n' "Hyprland --verify-config no dio OK con hyprland.lua; salida:"; echo "$out" | tail -15 | sed 's/^/      /'; fi
  fi
  if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    c opt "Quickshell en marcha en esta sesión"               sh -c 'pgrep -x qs || pgrep -x quickshell'
  fi
  CHECK_BAD=$bad
  return 0
}

if [ $MODE = check ]; then
  check
  if [ "$CHECK_BAD" = 0 ]; then printf '\n\033[1;32mTodo en orden.\033[0m\n'; exit 0
  else printf '\n\033[1;31m%s problema(s).\033[0m Ejecuta ./install.sh para repararlos.\n' "$CHECK_BAD"; exit 1; fi
fi

mkdir -p "$HOME/.cache"; LOG="$HOME/.cache/rice-install.log"
exec > >(tee -a "$LOG") 2>&1
echo "──── $(date) ────"

# ── 0. Comprobaciones previas ────────────────────────────────────────────────
say "0/8 Comprobaciones previas"
if [ $SYSTEM = 1 ]; then
  grep -q '^ID=fedora' "$OS_RELEASE" 2>/dev/null || die "Esto no parece Fedora ($OS_RELEASE). Usa --user-only para instalar solo la parte de usuario."
  has dnf || die "No encuentro dnf."
  echo "  Se pedirá tu contraseña de sudo una vez (paquetes, zsh por defecto y SDDM)."
  sudo -v || die "Sin sudo no puedo instalar paquetes. Usa --user-only si solo quieres la parte de usuario."
  ( while kill -0 $$ 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done ) &
  SUDO_KEEPALIVE=$!; trap 'kill $SUDO_KEEPALIVE 2>/dev/null' EXIT
fi
dl -o /dev/null -I https://github.com 2>/dev/null && ok "Conexión a internet" || warn "No llego a github.com: oh-my-zsh, Starship y el cursor podrían fallar"

# ── 1. Repositorios ──────────────────────────────────────────────────────────
# dnf ignora un repo caído (p. ej. un COPR sin versión para tu Fedora) en vez de abortar todo.
DNF=(sudo dnf -y --setopt=skip_if_unavailable=True)
copr_enabled() { local f; for f in /etc/yum.repos.d/_copr*"${1%%/*}:${1##*/}".repo; do [ -f "$f" ] && grep -q '^enabled=1' "$f" && return 0; done; return 1; }
copr_provides() { [ -n "$(dnf repoquery -q --repo "copr:copr.fedorainfracloud.org:${1%%/*}:${1##*/}" "$2" 2>/dev/null)" ]; }
hypr_ok() { ver_ge "$(hypr_version)" "$HYPR_MIN" 2>/dev/null && has hyprlock && has hyprpaper; }
qs_ok() { has qs; }
ensure_copr() { # ensure_copr <paquete> <función-ya-ok> <candidatos…>: garantiza un repo que traiga el paquete
  local pkg="$1" okf="$2" repo; shift 2
  if "$okf"; then ok "$pkg ya instalado: no hace falta COPR"; return 0; fi
  for repo in "$@"; do copr_enabled "$repo" && copr_provides "$repo" "$pkg" && { ok "$pkg disponible desde COPR $repo (ya activo)"; return 0; }; done
  for repo in "$@"; do
    if ! copr_enabled "$repo"; then
      sudo dnf copr enable -y "$repo" >/dev/null 2>&1 || { echo "  · $repo: sin paquetes para Fedora $FEDORA_VER, se prueba el siguiente"; continue; }
    fi
    if copr_provides "$repo" "$pkg"; then ok "COPR $repo activado ($pkg)"; return 0; fi
    sudo dnf copr disable -y "$repo" >/dev/null 2>&1; echo "  · $repo no trae $pkg, se desactiva"
  done
  die "Ningún COPR trae $pkg para Fedora $FEDORA_VER (probados: $*). Indica uno: HYPR_COPR=usuario/repo o QS_COPR=usuario/repo ./install.sh"
}
if [ $SYSTEM = 1 ]; then
  say "1/8 Repositorios (COPR)"
  FEDORA_VER="$(sed -n 's/^VERSION_ID=//p' "$OS_RELEASE" | tr -d '"')"
  if dnf --version 2>/dev/null | grep -qi dnf5; then plug=dnf5-plugins; else plug=dnf-plugins-core; fi
  rpm -q "$plug" >/dev/null 2>&1 || "${DNF[@]}" install "$plug" || die "No pude instalar $plug (necesario para 'dnf copr')"
  # Restos de intentos anteriores: un COPR activo que no existe para esta Fedora rompe cada 'dnf'
  copr_enabled byte0/hyprland && sudo dnf copr disable -y byte0/hyprland >/dev/null 2>&1 && echo "  · desactivado byte0/hyprland (no tiene Fedora $FEDORA_VER)"
  # shellcheck disable=SC2086
  ensure_copr hyprland  hypr_ok $HYPR_COPRS
  # shellcheck disable=SC2086
  ensure_copr quickshell qs_ok  $QS_COPRS
fi

# ── 2. Paquetes ──────────────────────────────────────────────────────────────
if [ $SYSTEM = 1 ]; then
  say "2/8 Paquetes"
  mapfile -t CORE  < <(pkg_section core)
  mapfile -t EXTRA < <(pkg_section extra)
  has ffmpeg || EXTRA+=(ffmpeg-free)               # si ya tienes ffmpeg (p. ej. RPM Fusion) no se toca
  mapfile -t miss < <(pkg_missing "${CORE[@]}")
  if [ ${#miss[@]} -gt 0 ]; then
    echo "  Faltan: ${miss[*]}"
    "${DNF[@]}" install "${miss[@]}" || "${DNF[@]}" install --refresh "${miss[@]}" || true
    mapfile -t miss < <(pkg_missing "${CORE[@]}")
    [ ${#miss[@]} -eq 0 ] || die "No se pudieron instalar: ${miss[*]}  (prueba: dnf info ${miss[0]})"
  fi
  ok "Paquetes imprescindibles instalados (${#CORE[@]})"
  v="$(hypr_version)"
  if ! ver_ge "${v:-0}" "$HYPR_MIN"; then
    echo "  Hyprland ${v:-?} es anterior a $HYPR_MIN (no entiende la config en Lua): actualizando…"
    "${DNF[@]}" upgrade --refresh hyprland hyprlock hyprpaper xdg-desktop-portal-hyprland || true
    v="$(hypr_version)"
    ver_ge "${v:-0}" "$HYPR_MIN" || die "Hyprland ${v:-?} < $HYPR_MIN. Ningún repo activo trae una versión con Lua; indica un COPR: HYPR_COPR=usuario/repo ./install.sh"
  fi
  ok "Hyprland $v"
  mapfile -t miss < <(pkg_missing "${EXTRA[@]}")
  if [ ${#miss[@]} -gt 0 ]; then
    "${DNF[@]}" install --skip-unavailable --skip-broken "${miss[@]}" || true
    mapfile -t miss < <(pkg_missing "${EXTRA[@]}")
    [ ${#miss[@]} -eq 0 ] || warn "Opcionales no disponibles (se sigue sin ellos): ${miss[*]}"
  fi
  ok "Paquetes opcionales revisados"
else
  say "1-2/8 Repositorios y paquetes: omitidos (--user-only)"
  for b in Hyprland hyprlock hyprpaper qs kitty zsh git magick jq rsync; do has "$b" || warn "Falta '$b' (instálalo o ejecuta ./install.sh sin --user-only)"; done
fi
has git   || die "Falta git."
has rsync || die "Falta rsync."

# ── 3. Shell: zsh, oh-my-zsh, plugins y Starship ─────────────────────────────
say "3/8 zsh, oh-my-zsh y Starship"
if has zsh; then
  if [ "$(basename "$(login_shell)")" = zsh ]; then ok "zsh ya es tu shell"
  elif [ $SYSTEM = 1 ]; then sudo usermod -s "$(command -v zsh)" "$USER" && ok "zsh es ahora tu shell (desde el próximo inicio de sesión)" || warn "No pude cambiar el shell: chsh -s $(command -v zsh)"
  else warn "zsh no es tu shell: chsh -s $(command -v zsh)"; fi
fi
if omz_ok; then ok "oh-my-zsh ya instalado"
else
  [ -e "$HOME/.oh-my-zsh" ] && { mv "$HOME/.oh-my-zsh" "$HOME/.oh-my-zsh.roto-$(date +%s)"; echo "  ~/.oh-my-zsh estaba incompleto: apartado"; }
  git clone -q --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh" && omz_ok && ok "oh-my-zsh instalado" || die "No pude clonar oh-my-zsh (¿red?)"
fi
P="$HOME/.oh-my-zsh/custom/plugins"; mkdir -p "$P"
for spec in "zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions" \
            "zsh-syntax-highlighting|https://github.com/zsh-users/zsh-syntax-highlighting"; do
  n="${spec%%|*}"; u="${spec##*|}"
  if [ -r "$P/$n/$n.zsh" ]; then ok "$n ya instalado"
  else rm -rf "${P:?}/$n"; git clone -q --depth 1 "$u" "$P/$n" && [ -r "$P/$n/$n.zsh" ] && ok "$n instalado" || die "No pude instalar $n"; fi
done
mkdir -p "$HOME/.local/bin"
if starship_ok; then ok "Starship ya instalado ($("$(starship_bin)" --version | head -1))"
else
  case "$(uname -m)" in aarch64) sa=aarch64-unknown-linux-musl ;; *) sa=x86_64-unknown-linux-musl ;; esac
  T="$(mktemp -d)"
  if dl -o "$T/s.tgz" "https://github.com/starship/starship/releases/latest/download/starship-$sa.tar.gz" && tar -xzf "$T/s.tgz" -C "$T" starship; then
    install -m755 "$T/starship" "$HOME/.local/bin/starship"
  elif [ $SYSTEM = 1 ]; then
    sudo dnf copr enable -y atim/starship && "${DNF[@]}" install starship || true
  fi
  rm -rf "$T"
  starship_ok && ok "Starship instalado" || die "No pude instalar Starship (https://starship.rs)"
fi

# ── 4. Fuentes, cursor e iconos ──────────────────────────────────────────────
say "4/8 Fuentes, cursor e iconos"
F="$HOME/.local/share/fonts/rice"; mkdir -p "$F"
if [ -n "$(rsync -a --checksum -i "$R/fonts/" "$F/")" ] || ! fc-list | grep -qi 'FiraCode Nerd Font'; then fc-cache -f >/dev/null 2>&1; fi
ok "Fuentes Rubik y FiraCode Nerd Font Mono"
I="$HOME/.local/share/icons"; mkdir -p "$I"
if [ -f "$I/Bibata-Modern-Ice/index.theme" ] || [ -f /usr/share/icons/Bibata-Modern-Ice/index.theme ]; then ok "Cursor Bibata ya instalado"
else
  T="$(mktemp -d)"
  if dl -o "$T/b.tar.xz" https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Ice.tar.xz && tar -xf "$T/b.tar.xz" -C "$T" && [ -f "$T/Bibata-Modern-Ice/index.theme" ]; then
    rm -rf "$I/Bibata-Modern-Ice"; mv "$T/Bibata-Modern-Ice" "$I/" && ok "Cursor Bibata instalado"
  else warn "No pude descargar el cursor Bibata (se usará el predeterminado)"; fi
  rm -rf "$T"
fi
mkdir -p "$HOME/.icons/default"; printf '[Icon Theme]\nName=Default\nInherits=Bibata-Modern-Ice\n' > "$HOME/.icons/default/index.theme"
for v in 3.0 4.0; do mkdir -p "$C/gtk-$v"
  printf '[Settings]\ngtk-application-prefer-dark-theme=1\ngtk-cursor-theme-name=Bibata-Modern-Ice\ngtk-cursor-theme-size=24\ngtk-icon-theme-name=Papirus-Dark\ngtk-font-name=Rubik 11\n' > "$C/gtk-$v/settings.ini"; done
if has gsettings; then
  gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice' 2>/dev/null
  gsettings set org.gnome.desktop.interface cursor-size 24 2>/dev/null
  gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' 2>/dev/null
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null
fi
ok "GTK: oscuro, Papirus, Bibata"

# ── 5. Configuración (~/.config) ─────────────────────────────────────────────
say "5/8 Configuración"
# Generados por rice-theme (se crean en la fase 6) y estado del usuario (solo se crean si faltan).
GENERATED=(kitty/theme.conf hypr/colors.lua hypr/colors.conf fastfetch/config.jsonc zsh/fzf-theme.zsh)
STATEFILES=(hypr/wallpaper.state hypr/avatar.png hypr/widgets.json hypr/spotify-api.json hypr/monitors.lua hypr/hyprpaper.conf
            rice/theme.json rice/shell.json rice/themes/wallpaper.json)
STAGE="$(mktemp -d)"; trap 'rm -rf "$STAGE"; [ -n "${SUDO_KEEPALIVE:-}" ] && kill $SUDO_KEEPALIVE 2>/dev/null' EXIT
cp -a "$R/config/." "$STAGE/"
# Reescribe @HOME@ conservando la fecha original (si no, rsync vería "cambios" en cada ejecución)
while IFS= read -r f; do sed -i "s#@HOME@#$HOME#g" "$f"; touch -r "$R/config/${f#"$STAGE"/}" "$f"; done \
  < <(grep -rIl '@HOME@' "$STAGE" 2>/dev/null)
backup() { # backup <ruta>: copia una sola vez por ejecución a $BK
  [ -e "$1" ] || return 0
  local dst="$BK/${1#"$HOME"/}"; [ -e "$dst" ] && return 0
  mkdir -p "$(dirname "$dst")"; cp -a "$1" "$dst"
}
sync_dir() { # sync_dir <subdir>: copia el subdir del repo a ~/.config sin tocar generados, estado ni archivos ajenos
  local d="$1" del="" f ex=()
  for f in "${GENERATED[@]}" "${STATEFILES[@]}"; do [[ "$f" == "$d/"* ]] && ex+=(--exclude="/${f#"$d"/}"); done
  ex+=(--exclude='*.bak*' --exclude='__pycache__')
  mkdir -p "$C/$d"
  local changes; changes="$(rsync -a -O --checksum -n -i $del "${ex[@]}" "$STAGE/$d/" "$C/$d/")"
  if [ -n "$changes" ]; then
    backup "$C/$d"
    rsync -a -O --checksum $del "${ex[@]}" "$STAGE/$d/" "$C/$d/"
    ok "$d actualizado ($(echo "$changes" | wc -l) cambios)"
  else ok "$d ya al día"; fi
}
RICE_DIRS=(quickshell hypr rice kitty zsh fastfetch git systemd/user)
for d in "${RICE_DIRS[@]}"; do sync_dir "$d"; done
# Limpieza: solo se borran archivos que instaló el propio rice en una ejecución anterior y que ya no
# están en el repo (registro en ~/.local/state/rice/manifest). Lo que no instaló el rice no se toca.
MAN="$HOME/.local/state/rice/manifest"; mkdir -p "$(dirname "$MAN")"
NEWMAN="$(cd "$STAGE" && for d in "${RICE_DIRS[@]}"; do find "$d" -type f ! -name '*.bak*' ! -path '*__pycache__*'; done | sort)"
if [ -f "$MAN" ]; then
  while IFS= read -r f; do
    [ -n "$f" ] && [ -f "$C/$f" ] || continue
    printf '%s\n' "${GENERATED[@]}" "${STATEFILES[@]}" | grep -qxF "$f" && continue
    backup "$C/$f"; rm -f "$C/$f"; echo "  · quitado $f (ya no forma parte del rice)"
  done < <(comm -23 "$MAN" <(echo "$NEWMAN"))
fi
echo "$NEWMAN" > "$MAN"
# Estado: solo si falta
[ -f "$C/hypr/monitors.lua" ]     || { cp "$R/templates/monitors.lua" "$C/hypr/monitors.lua"; ok "monitors.lua creado (ajústalo con: hyprctl monitors)"; }
[ -f "$C/hypr/spotify-api.json" ] || { cp "$R/templates/spotify-api.json" "$C/hypr/spotify-api.json"; chmod 600 "$C/hypr/spotify-api.json"; }
[ -f "$C/rice/theme.json" ]       || cp "$STAGE/rice/theme.json" "$C/rice/theme.json"
[ -f "$C/rice/shell.json" ]       || cp "$STAGE/rice/shell.json" "$C/rice/shell.json"
[ -f "$C/rice/themes/wallpaper.json" ] || cp "$STAGE/rice/themes/wallpaper.json" "$C/rice/themes/wallpaper.json"
python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$C/rice/theme.json" 2>/dev/null || { backup "$C/rice/theme.json"; cp "$STAGE/rice/theme.json" "$C/rice/theme.json"; warn "theme.json estaba dañado: restaurado"; }
chmod +x "$C"/hypr/scripts/* "$C/rice/apply.py" 2>/dev/null
ln -sfn "$C/rice/apply.py" "$HOME/.local/bin/rice-theme"
# ~/.zshrc
ZT="$HOME/.zshrc"; [ $KEEPZ = 1 ] && ZT="$HOME/.zshrc.rice"
if cmp -s "$R/home/zshrc" "$ZT"; then ok "$(basename "$ZT") ya al día"
else backup "$ZT"; cp "$R/home/zshrc" "$ZT"; ok "$(basename "$ZT") instalado"; fi
[ $KEEPZ = 1 ] && warn "~/.zshrc intacto (--keep-zshrc); el del rice está en ~/.zshrc.rice"
has systemctl && systemctl --user daemon-reload 2>/dev/null
if [ -d "$BK" ]; then
  ok "Respaldo de lo reemplazado: $BK"
  ls -dt "$HOME"/.config-backup/rice-* 2>/dev/null | tail -n +6 | xargs -r rm -rf   # se guardan los 5 últimos
fi

# ── 6. Tema, fondos, avatar y bloqueo ────────────────────────────────────────
say "6/8 Tema, fondos y pantalla de bloqueo"
python3 "$C/rice/apply.py" --no-reload >/dev/null && ok "Tema '$(python3 -c "import json;print(json.load(open('$C/rice/theme.json'))['name'])")' aplicado (kitty, Hyprland, hyprlock, Starship, fzf, fastfetch)" \
  || die "No pude generar los colores del tema (python3 $C/rice/apply.py)"
mkdir -p "$WALL"
rsync -a --ignore-existing "$R"/wallpapers/*-1440p.png "$R"/wallpapers/*-1080p.png "$WALL/"
if [ ! -f "$WALL/a-street-with-buildings--1440p.png" ] && has magick; then
  "$C/hypr/scripts/wallpaper.sh" import "$R/wallpapers/a-street-with-buildings-.png" a-street-with-buildings- >/dev/null 2>&1 || warn "No pude convertir el fondo del escritorio"
fi
"$C/hypr/scripts/wallpaper.sh" repair >/dev/null && ok "Fondos listos ($(. "$C/hypr/wallpaper.state"; echo "escritorio: $DESKTOP, bloqueo: $LOCK"))"
if [ ! -s "$C/hypr/avatar.png" ]; then
  if [ -s "$HOME/.face" ] && has magick; then magick "$HOME/.face" -resize 512x512^ -gravity center -extent 512x512 "$C/hypr/avatar.png"
  elif has magick; then
    L="$(getent passwd "$USER" | cut -d: -f5 | cut -c1)"; L="${L:-${USER:0:1}}"
    font="$(fc-match -f '%{file}' 'Rubik' 2>/dev/null)"
    magick -size 512x512 xc:none -fill '#2a2f3a' -draw 'circle 256,256 256,0' -fill '#e6e8ee' \
      ${font:+-font "$font"} -pointsize 240 -gravity center -annotate +0+0 "${L^^}" "$C/hypr/avatar.png" 2>/dev/null
  fi
  [ -s "$C/hypr/avatar.png" ] && ok "Avatar por defecto creado (cámbialo en ~/.config/hypr/avatar.png)"
fi
"$C/hypr/scripts/lock.sh" --prepare && grep -q '^background' "$HOME/.cache/hyprlock/monitors.conf" && ok "Fondo de bloqueo preparado" || warn "No pude preparar el fondo del bloqueo (se usará una captura difuminada)"

# ── 7. Login (SDDM) ──────────────────────────────────────────────────────────
if [ $SYSTEM = 1 ] && [ $SDDM = 1 ]; then
  say "7/8 Login (SDDM)"
  sudo sh "$R/sddm/install.sh" "$USER" && ok "SDDM activo con el tema cubi" || warn "Falló la instalación de SDDM"
else
  say "7/8 Login (SDDM): omitido"
fi

# ── 8. Recargar si estamos dentro de Hyprland, y comprobar ───────────────────
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && has hyprctl; then
  say "8/8 Recargando la sesión actual"
  hyprctl reload >/dev/null 2>&1 && ok "Hyprland recargado"
  pkill -x qs 2>/dev/null; pkill -x quickshell 2>/dev/null; sleep 0.5
  setsid -f qs -p "$C/quickshell/bar" >/dev/null 2>&1 < /dev/null && ok "Quickshell reiniciado"
  "$C/hypr/scripts/wallpaper.sh" apply >/dev/null 2>&1 && ok "Fondo aplicado"
else
  say "8/8 Comprobación final"
fi
check

echo
if [ "$CHECK_BAD" = 0 ]; then
  printf '\033[1;32m✔ Rice instalado.\033[0m\n'
else
  printf '\033[1;31m✘ Quedan %s problema(s) (arriba, en rojo).\033[0m Corrígelos y vuelve a ejecutar ./install.sh\n' "$CHECK_BAD"
fi
[ ${#WARNS[@]} -gt 0 ] && { echo "Avisos:"; printf '  • %s\n' "${WARNS[@]}"; }
cat <<MSG

Siguiente paso:
  • Reinicia (o cierra sesión) y entra en «Hyprland» desde SDDM.
  • ¿Monitores distintos? Edita ~/.config/hypr/monitors.lua (nombres con: hyprctl monitors). Nunca se pisa.
  • Diagnóstico en cualquier momento: ./install.sh --check      Registro: $LOG
MSG
[ "$CHECK_BAD" = 0 ]
