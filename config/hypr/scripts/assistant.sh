#!/usr/bin/env bash
# Asistente de escritorio (Nexora + avatar 3D). Un solo punto de control para Quickshell, atajos y systemd.
#   toggle | show | hide   ventana del asistente (espacio especial de Hyprland, se desliza desde la derecha)
#   init                   crea ~/.config/nexora/env con valores por defecto si no existe
#   settings               abre el panel de ajustes de Quickshell
#   status                 estado en líneas clave=valor (lo lee Quickshell)
#   restart | stop         reinicia o detiene la API y la web
#   apply                  tras guardar ajustes: reinicia la API y arranca/detiene Kokoro según el TTS elegido
#   kokoro-install|start|stop   TTS local (contenedor Docker con GPU, puerto 8881)
#   qwen-start|stop        TTS local Qwen3-TTS (servidor propio con GPU, puerto 8890)
#   voices-start|stop      voces ligeras (Piper/Supertonic, GPU opcional, puerto 8891)
#   llm-start|stop         modelo de lenguaje local (llama-server con el GGUF de LM Studio; LLM_PROVIDER=local)
#   voice-test <qwen|voices> <voz>   reproduce una frase de prueba con esa voz
#   run-api | run-web | run-llm   los usan las unidades de systemd
set -u
CONF="$HOME/.config/nexora/env"
REPO="$HOME/code/nexora"
WEB_PORT=5180
URL="http://127.0.0.1:$WEB_PORT/?kiosk"
# Servidor Kokoro propio de este PC (GPU NVIDIA, imagen CUDA 12.8 para la serie RTX 50), aparte del de otros proyectos.
KOKORO_IMAGE="ghcr.io/remsky/kokoro-fastapi-gpu:latest-cu128"
CLASS="chrome-127.0.0.1__-Default"   # app_id que Chrome asigna a la ventana --app (ignora --class en Wayland)
QS=(qs -p "$HOME/.config/quickshell/bar")
SELF="$(readlink -f "$0")"

node_bin() {
  command -v node 2>/dev/null && return
  ls -d "$HOME"/.nvm/versions/node/*/bin/node 2>/dev/null | sort -V | tail -1
}
conf_get() { grep -m1 "^$1=" "$CONF" 2>/dev/null | cut -d= -f2-; }
# Configurado = hay clave de OpenRouter, o se usa un modelo local (LLM_PROVIDER=local) con su modelo definido.
configured() { [ -n "$(conf_get OPENROUTER_API_KEY)" ] || { llm_local && [ -n "$(conf_get LLM_MODEL)" ]; }; }
llm_local() { [ "$(conf_get LLM_PROVIDER)" = local ]; }
llm_base() { local b; b=$(conf_get LLM_BASE_URL); echo "${b:-http://127.0.0.1:8088/v1}"; }
# Espera (máx. 90 s) a que llama-server cargue el modelo: la API comprueba el contexto al arrancar.
wait_llm() { local i; for i in $(seq 1 180); do llm_up && return 0; sleep 0.5; done; return 1; }
llm_up() { curl -fs --max-time 1 "$(llm_base | sed 's#/v1/*$##')/health" 2>/dev/null | grep -q ok; }
unit_state() { systemctl --user is-active "$1" 2>/dev/null || true; }
window_addr() { hyprctl clients -j | jq -r --arg c "$CLASS" '[.[] | select(.class==$c)][0].address // empty'; }
# Cierra la ventana del avatar: queda viva en segundo plano y, si no, seguiría con la interfaz anterior tras una actualización.
close_window() { local a; a=$(window_addr); [ -n "$a" ] && hyprctl dispatch "hl.dsp.window.close({ window = \"address:$a\" })" >/dev/null; return 0; }
kokoro_up() { curl -fs --max-time 1 "$(conf_get KOKORO_BASE_URL)/health" >/dev/null 2>&1; }
qwen_up() { curl -fs --max-time 1 "$(conf_get QWEN_BASE_URL)/health" 2>/dev/null | grep -q healthy; }
qwen_wanted() { [ "$(conf_get TTS_PROVIDER)" = qwen ] && [ "$(conf_get TTS_ENABLED)" != false ]; }
voices_up() { curl -fs --max-time 1 "$(conf_get VOICES_BASE_URL)/health" 2>/dev/null | grep -q healthy; }
voices_wanted() { [ "$(conf_get TTS_PROVIDER)" = voices ] && [ "$(conf_get TTS_ENABLED)" != false ]; }
kokoro_wanted() { [ "$(conf_get TTS_PROVIDER)" = kokoro ] && [ "$(conf_get TTS_ENABLED)" != false ]; }

ensure_conf() {
  [ -f "$CONF" ] && return
  mkdir -p "$(dirname "$CONF")"
  umask 077
  cat > "$CONF" <<ENV
NEXORA_PROVIDERS=live
NODE_ENV=production
NEXORA_TRACE=false
HOST=127.0.0.1
PORT=3187
LOG_LEVEL=info
WEB_ORIGIN=http://127.0.0.1:$WEB_PORT
AVATARS_DIR=../../playground/avatars
ENTITY_AVATAR=alexia
OPENROUTER_API_KEY=
GEMINI_API_KEY=
LLM_MODEL=anthropic/claude-haiku-5.5
DECISION_MODEL=typesafe/jev-1.14
TTS_ENABLED=true
TTS_STREAMING=true
TTS_PROVIDER=gemini
TTS_MODEL=gemini-3.8-flash-lite-tts
TTS_VOICE=Kore
KOKORO_BASE_URL=http://127.0.0.1:8881
KOKORO_VOICE=ef_dora
QWEN_BASE_URL=http://127.0.0.1:8890
QWEN_MODEL=qwen3-tts
QWEN_LANGUAGE=Spanish
ENV
}

# El backend y los avatares responden (a través del propio servidor web, que hace de proxy).
api_ready() { curl -fs --max-time 2 "http://127.0.0.1:$WEB_PORT/api/avatars" 2>/dev/null | jq -e '(.avatars | length) > 0' >/dev/null 2>&1; }
# Espera (máx. ~60 s) a que todo responda: si la ventana carga antes, la página se queda con "no hay avatares / no está en marcha" y no reintenta.
wait_ready() { local i; for i in $(seq 1 120); do api_ready && { ! llm_local || llm_up; } && return 0; sleep 0.5; done; return 1; }
start_core() {
  ensure_conf
  systemctl --user start nexora-web.service
  llm_local && ! llm_up && systemctl --user start nexora-llm.service
  llm_local && wait_llm
  configured && systemctl --user start nexora-api.service
  kokoro_wanted && ! kokoro_up && systemctl --user start nexora-kokoro.service
  qwen_wanted && ! qwen_up && systemctl --user start nexora-qwen-tts.service
  voices_wanted && ! voices_up && systemctl --user start nexora-voices.service
  return 0
}

launch_window() {
  [ -n "$(window_addr)" ] && return
  setsid -f google-chrome-stable --app="$URL" --class="$CLASS" --name="$CLASS" \
    --user-data-dir="$HOME/.local/share/nexora/chrome" --password-store=basic --no-first-run --no-default-browser-check \
    --ozone-platform=wayland --disable-features=TranslateUI >/dev/null 2>&1
  for _ in $(seq 60); do [ -n "$(window_addr)" ] && return; sleep 0.25; done
}

# La ventana es flotante y "pinned" (visible en todos los workspaces, sin quitar el control de lo que hay debajo).
# Oculta = en el espacio especial "assistant". No se usa ese espacio para mostrarla: al hacer clic fuera, Hyprland lo cierra.
special_open() { hyprctl clients -j | jq -e --arg c "$CLASS" '[.[] | select(.class==$c and .pinned)] | length > 0' >/dev/null 2>&1; }
focus_window() { local a; a=$(window_addr); [ -n "$a" ] && hyprctl dispatch "hl.dsp.focus({ window = \"address:$a\" })" >/dev/null; }
# Ancla la ventana al borde derecho del monitor donde está (mismas medidas que la regla de hyprland.lua).
# Recuadro del asistente: esquina inferior derecha del monitor. Las mismas cifras están en la regla de hyprland.lua.
BOX_W=400; BOX_H=560; BOX_MARGIN=16
snap_window() {
  local w x y h ww
  w=$(hyprctl clients -j | jq -c --arg c "$CLASS" '[.[] | select(.class==$c and .pinned)][0] // empty'); [ -n "$w" ] || return 0
  read -r x y ww h <<<"$(hyprctl monitors -j | jq -r --argjson w "$w" --argjson bw "$BOX_W" --argjson bh "$BOX_H" --argjson bm "$BOX_MARGIN" '.[] | select(.id==$w.monitor) | "\(.x + (.width / .scale | floor) - $bw - $bm) \(.y + (.height / .scale | floor) - $bh - $bm) \($bw) \($bh)"')"
  [ -n "$x" ] || return 0
  # solo si se movió (evita parpadeos y trabajo de más)
  [ "$(echo "$w" | jq -r '"\(.at[0]) \(.at[1]) \(.size[0]) \(.size[1])"')" = "$x $y $ww $h" ] && return 0
  hyprctl dispatch "hl.dsp.window.resize({ x = $ww, y = $h, relative = false, window = \"address:$(echo "$w" | jq -r .address)\" })" >/dev/null
  hyprctl dispatch "hl.dsp.window.move({ x = $x, y = $y, relative = false, window = \"address:$(echo "$w" | jq -r .address)\" })" >/dev/null
  # el tamaño cambia desde el centro: primero tamaño, luego posición
}
show_window() {
  local a ws; a=$(window_addr); [ -n "$a" ] || return 1
  special_open || {
    ws=$(hyprctl activeworkspace -j | jq -r .id)
    hyprctl dispatch "hl.dsp.window.move({ workspace = \"$ws\", follow = false, window = \"address:$a\" })" >/dev/null
    hyprctl dispatch "hl.dsp.window.pin({ window = \"address:$a\" })" >/dev/null
  }
  snap_window
  focus_window
}
hide_window() {
  local a; a=$(window_addr); [ -n "$a" ] || return 0
  special_open && hyprctl dispatch "hl.dsp.window.pin({ window = \"address:$a\" })" >/dev/null
  hyprctl dispatch "hl.dsp.window.move({ workspace = \"special:assistant\", follow = false, window = \"address:$a\" })" >/dev/null
}
toggle_special() { if special_open; then hide_window; else show_window; fi; }

case "${1:-toggle}" in
  show|toggle)
    if ! configured; then exec "${QS[@]}" ipc call assistant settings; fi
    # Camino rápido: la ventana ya existe (el modelo 3D sigue cargado en memoria), solo se muestra u oculta.
    if [ -n "$(window_addr)" ]; then
      if api_ready; then
        # visible sin foco -> enfocar; visible con foco -> ocultar (toggle); oculta -> mostrar
        if special_open; then
          if [ "$1" = toggle ] && [ "$(hyprctl activewindow -j | jq -r .class)" = "$CLASS" ]; then hide_window; else focus_window; fi
        else show_window; fi
        exit 0
      fi
      # la ventana sobrevivió pero el backend no (reinicio parcial, caída): se levanta todo y se recarga la ventana
      start_core; wait_ready; close_window
      for _ in $(seq 1 20); do [ -z "$(window_addr)" ] && break; sleep 0.25; done
    else
      start_core; wait_ready
    fi
    launch_window
    # tras abrir la ventana nueva Hyprland tarda un instante en asentarla: se reintenta hasta verla mostrada
    for _ in $(seq 1 20); do sleep 0.5; [ -n "$(window_addr)" ] && break; done
    sleep 0.5; show_window
    ;;
  hide) hide_window ;;
  boot)
    # Al iniciar sesión: deja todo listo (servicios + ventana oculta con el avatar ya cargado) para que SUPER+A sea instantáneo.
    configured || exit 0
    start_core; wait_ready || exit 1
    [ -n "$(window_addr)" ] || launch_window
    ;;
  snap) snap_window ;;
  init) ensure_conf ;;
  settings) "${QS[@]}" ipc call assistant settings ;;
  restart) ensure_conf; systemctl --user restart nexora-web.service; llm_local && { systemctl --user restart nexora-llm.service; wait_llm; }; configured && systemctl --user restart nexora-api.service; close_window ;;
  stop) systemctl --user stop nexora-api.service nexora-web.service nexora-llm.service; a=$(window_addr); [ -n "$a" ] && hyprctl dispatch "hl.dsp.window.close({ window = \"address:$a\" })" >/dev/null ;;
  apply)
    ensure_conf
    systemctl --user start nexora-web.service
    if llm_local; then systemctl --user restart nexora-llm.service; wait_llm; else systemctl --user stop nexora-llm.service; fi
    if configured; then systemctl --user restart nexora-api.service; else systemctl --user stop nexora-api.service; fi
    if kokoro_wanted; then kokoro_up || systemctl --user start nexora-kokoro.service; else systemctl --user stop nexora-kokoro.service; fi
    if voices_wanted; then voices_up || systemctl --user start nexora-voices.service; else systemctl --user stop nexora-voices.service; fi
    if qwen_wanted; then qwen_up || systemctl --user start nexora-qwen-tts.service; else systemctl --user stop nexora-qwen-tts.service; fi
    
    close_window
    ;;
  status)
    echo "configured=$(configured && echo yes || echo no)"
    echo "api=$(unit_state nexora-api.service)"
    echo "web=$(unit_state nexora-web.service)"
    echo "kokoro=$(kokoro_up && echo up || echo down)"
    echo "kokoro_own=$(unit_state nexora-kokoro.service)"
    v=$(curl -fs --max-time 1 "http://127.0.0.1:${API_PORT:-$(conf_get PORT)}/api/version" 2>/dev/null)
    echo "version_assistant=$(echo "$v" | jq -r '.assistant // empty' 2>/dev/null)"
    echo "version_nexora=$(echo "$v" | jq -r '.nexora // empty' 2>/dev/null)"
    echo "voices=$(voices_up && echo up || echo down)"
    echo "voices_own=$(unit_state nexora-voices.service)"
    echo "qwen=$(qwen_up && echo up || echo down)"
    echo "qwen_own=$(unit_state nexora-qwen-tts.service)"
    echo "qwen_voices=$(curl -fs --max-time 1 "$(conf_get QWEN_BASE_URL)/health" 2>/dev/null | jq -r '(.voices // []) | join(",")' 2>/dev/null)"
    echo "kokoro_image=$(docker image inspect "$KOKORO_IMAGE" >/dev/null 2>&1 && echo yes || echo no)"
    echo "llm_provider=$(conf_get LLM_PROVIDER)"
    echo "llm=$(llm_local && { llm_up && echo up || echo down; } || echo off)"
    echo "llm_own=$(unit_state nexora-llm.service)"
    echo "window=$([ -n "$(window_addr)" ] && echo yes || echo no)"
    ;;
  kokoro-install) exec docker pull "$KOKORO_IMAGE" ;;
  kokoro-start) systemctl --user start nexora-kokoro.service ;;
  kokoro-stop) systemctl --user stop nexora-kokoro.service ;;
  voices-start) systemctl --user start nexora-voices.service ;;
  voices-stop) systemctl --user stop nexora-voices.service ;;
  voice-test)
    case "$2" in
      qwen) base=$(conf_get QWEN_BASE_URL); lang=$(conf_get QWEN_LANGUAGE) ;;
      voices) base=$(conf_get VOICES_BASE_URL); lang=$(conf_get VOICES_LANGUAGE) ;;
      *) exit 2 ;;
    esac
    body=$(jq -n --arg v "$3" --arg l "${lang:-Spanish}" '{model:"test",input:"Hola, soy tu asistente. Así sueno cuando hablamos; dime si te gusta esta voz.",voice:$v,language:$l,response_format:"pcm",stream:true}')
    curl -fs --max-time 60 -H 'content-type: application/json' -d "$body" "$base/v1/audio/speech" | paplay --raw --rate=24000 --channels=1 --format=s16le ;;
  llm-start) systemctl --user start nexora-llm.service ;;
  llm-stop) systemctl --user stop nexora-llm.service ;;
  qwen-start) systemctl --user start nexora-qwen-tts.service ;;
  qwen-stop) systemctl --user stop nexora-qwen-tts.service ;;
  run-api) cd "$HOME/code/nexora-assistant" && exec "$(node_bin)" dist/main.js ;;
  run-llm)
    # llama-server con el runtime CUDA que trae LM Studio (se elige el más reciente) y el GGUF configurado.
    be=$(ls -d "$HOME"/.lmstudio/extensions/backends/llama.cpp-linux-x86_64-nvidia-cuda12-avx2-* 2>/dev/null | sort -V | tail -1)
    bin="${LLM_SERVER_BIN:-$(conf_get LLM_SERVER_BIN)}"; bin="${bin:-$be/llama-server}"
    gguf=$(conf_get LLM_MODEL_PATH)
    [ -x "$bin" ] || { echo "run-llm: no encuentro llama-server ($bin)" >&2; exit 1; }
    [ -f "$gguf" ] || { echo "run-llm: LLM_MODEL_PATH no apunta a un GGUF ($gguf)" >&2; exit 1; }
    # La GPU debe tener sitio: si LM Studio mantiene el modelo cargado, hay que descargarlo (lms unload --all).
    need_mb=$(( $(stat -c %s "$gguf") / 1048576 + 2500 ))
    free_mb=$(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits 2>/dev/null | head -1)
    if [ -n "${free_mb:-}" ] && [ "$free_mb" -lt "$need_mb" ]; then
      echo "run-llm: poca VRAM libre (${free_mb} MiB, hacen falta ~${need_mb} MiB). Si LM Studio tiene el modelo cargado: lms unload --all" >&2; exit 1
    fi
    port=$(llm_base | sed -E 's#^https?://[^:/]+:([0-9]+).*#\1#')
    args=(-m "$gguf" --alias "$(conf_get LLM_MODEL)" --host 127.0.0.1 --port "${port:-8088}" -np 1 --jinja -ngl 99 -fa on --reasoning-format deepseek)
    ctx=$(conf_get LLM_CONTEXT_TOKENS); [ -n "$ctx" ] && args+=(-c "$ctx")   # sin cifra, la del modelo
    [ "$(conf_get LLM_REASONING)" = off ] && args+=(--reasoning off)
    # shellcheck disable=SC2206
    extra=( $(conf_get LLM_SERVER_ARGS) ); args+=("${extra[@]}")
    exec env LD_LIBRARY_PATH="$(dirname "$bin"):$HOME/.lmstudio/extensions/backends/vendor/linux-llama-cuda12-vendor-v1" "$bin" "${args[@]}" ;;
  run-web) exec env ASSISTANT_PORT="$WEB_PORT" ASSISTANT_WEB_DIST="$REPO/apps/web/dist" ASSISTANT_SCRIPT="$SELF" "$(node_bin)" "$HOME/.config/hypr/scripts/assistant-host.mjs" ;;
  *) echo "uso: $0 toggle|show|hide|boot|settings|status|restart|stop|apply|kokoro-*" >&2; exit 2 ;;
esac
