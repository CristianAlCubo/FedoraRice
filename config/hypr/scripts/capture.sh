#!/bin/sh
# Captura de pantalla / grabación de video (Wayland: grim, slurp, wf-recorder).
# Uso: capture.sh shot-full | shot-region | rec-full | rec-region | rec-pause | rec-resume | rec-stop
# La pausa corta la grabación en segmentos; al detener se unen con ffmpeg.
# stdin cerrado: si lo lanza Quickshell recibe un pipe abierto y slurp se queda esperando una lista de regiones por stdin.
exec </dev/null
SHOTS="$(xdg-user-dir PICTURES)/Capturas"
VIDS="$(xdg-user-dir VIDEOS)/Grabaciones"
REC="$HOME/.cache/cubi/rec"          # sesión de grabación en curso
mkdir -p "$SHOTS" "$VIDS" "$HOME/.cache/cubi"
echo "$(date +%T) capture.sh $*" >> "$HOME/.cache/cubi/capture.log"

need() { command -v "$1" >/dev/null 2>&1 || { notify-send -a Captura "Falta $1" "Instálalo con: sudo dnf install $1"; exit 1; }; }
region() { slurp -d -b '#00000066' -c '#ffffffff' -w 2 || exit 0; }   # Esc cancela
monitor() { hyprctl monitors -j | python3 -c "import json,sys;print(next(m['name'] for m in json.load(sys.stdin) if m['focused']))"; }

# state: "<recording|paused> <segundos acumulados> <epoch del segmento actual>"
set_state() { echo "$1 $2 $3" > "$REC/state.tmp"; mv "$REC/state.tmp" "$REC/state"; }
wait_recorder_exit() { i=0; while pgrep -x wf-recorder >/dev/null && [ $i -lt 50 ]; do sleep 0.1; i=$((i+1)); done; }

start_segment() {
  n=$(( $(cat "$REC/n" 2>/dev/null || echo 0) + 1 )); echo $n > "$REC/n"
  seg=$(printf "%s/seg_%03d.mp4" "$REC" $n)
  # audio del sistema: monitor de la salida predeterminada (lo que suena por los auriculares)
  sink=$(pactl get-default-sink 2>/dev/null)
  set -- ; [ -n "$sink" ] && set -- "--audio=$sink.monitor" -C aac
  setsid wf-recorder "$@" "$(cat "$REC/opt")" "$(cat "$REC/val")" \
    -c libx264 -p preset=veryfast -p crf=23 \
    -F 'scale=trunc(iw/2)*2:trunc(ih/2)*2' -f "$seg" >/dev/null 2>&1 &
}

case "$1" in
  shot-full|shot-region)
    need grim
    sleep 0.4                                   # deja que el panel termine de cerrarse
    f="$SHOTS/captura_$(date +%Y-%m-%d_%H-%M-%S).png"
    if [ "$1" = shot-region ]; then need slurp; g=$(region); grim -g "$g" "$f"; else grim -o "$(monitor)" "$f"; fi
    [ -s "$f" ] || exit 1
    wl-copy < "$f"
    notify-send -a Captura -i "$f" "Captura guardada" "Copiada al portapapeles\n$f"
    ;;
  rec-full|rec-region)
    need wf-recorder
    { pgrep -x wf-recorder >/dev/null || [ -f "$REC/state" ]; } && { notify-send -a Captura "Ya hay una grabación en curso"; exit 0; }
    sleep 0.4
    if [ "$1" = rec-region ]; then need slurp; g=$(region); o=-g; v=$g; else o=-o; v=$(monitor); fi
    rm -rf "$REC"; mkdir -p "$REC"
    echo "$o" > "$REC/opt"; echo "$v" > "$REC/val"
    echo "$VIDS/grabacion_$(date +%Y-%m-%d_%H-%M-%S).mp4" > "$REC/name"
    start_segment
    set_state recording 0 "$(date +%s)"
    ;;
  rec-pause)
    [ -f "$REC/state" ] || exit 0
    read st base since < "$REC/state"
    [ "$st" = recording ] || exit 0
    pkill -INT -x wf-recorder; wait_recorder_exit
    set_state paused $(( base + $(date +%s) - since )) 0
    ;;
  rec-resume)
    [ -f "$REC/state" ] || exit 0
    read st base since < "$REC/state"
    [ "$st" = paused ] || exit 0
    start_segment
    set_state recording "$base" "$(date +%s)"
    ;;
  rec-stop)
    [ -d "$REC" ] || exit 0
    pkill -INT -x wf-recorder; wait_recorder_exit
    rm -f "$REC/state"                          # la barra deja de mostrar la grabación
    out=$(cat "$REC/name"); segs=$(ls "$REC"/seg_*.mp4 2>/dev/null)
    cnt=$(echo "$segs" | grep -c .)
    if [ "$cnt" -eq 0 ]; then notify-send -a Captura "No se guardó nada" "La grabación quedó vacía"; rm -rf "$REC"; exit 1
    elif [ "$cnt" -eq 1 ]; then mv "$segs" "$out"
    else
      for s in $segs; do echo "file '$s'"; done > "$REC/list.txt"
      ffmpeg -v error -f concat -safe 0 -i "$REC/list.txt" -c copy "$out" || { notify-send -a Captura "Error al unir los segmentos" "Quedan en $REC"; exit 1; }
    fi
    rm -rf "$REC"
    # aviso con botón para abrir la carpeta (queda esperando en segundo plano la respuesta)
    (
      r=$(notify-send -a Captura -A "open=Abrir carpeta" --wait "Grabación guardada" "$out")
      if [ "$r" = open ]; then
        if command -v nautilus >/dev/null 2>&1; then nautilus --select "$out" >/dev/null 2>&1
        else xdg-open "$(dirname "$out")" >/dev/null 2>&1; fi
      fi
    ) >/dev/null 2>&1 &
    ;;
esac
