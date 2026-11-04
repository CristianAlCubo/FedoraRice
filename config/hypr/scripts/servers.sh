#!/bin/sh
# Estado de los hosts de ~/.ssh/config: idx|alias|host|usuario|up/down|ms   (conexión TCP al puerto SSH)
CFG="$HOME/.ssh/config"
[ -f "$CFG" ] || exit 0
awk 'function flush(){ if (h != "" && h !~ /[*?]/) print ++n "|" h "|" hn "|" u "|" p }
     /^[ \t]*[Hh]ost[ \t]/ { flush(); h=$2; hn=h; u=""; p=22; next }
     /^[ \t]*[Hh]ost[Nn]ame[ \t]/ { hn=$2 }
     /^[ \t]*[Uu]ser[ \t]/ { u=$2 }
     /^[ \t]*[Pp]ort[ \t]/ { p=$2 }
     END { flush() }' "$CFG" |
while IFS='|' read -r i a h u p; do
  (
    s=$(date +%s%N)
    if timeout 3 bash -c "exec 3<>/dev/tcp/$h/$p" 2>/dev/null; then
      e=$(date +%s%N); echo "$i|$a|$h|$u|up|$(( (e - s) / 1000000 ))"
    else
      echo "$i|$a|$h|$u|down|0"
    fi
  ) &
done | sort -t'|' -k1,1n
wait
