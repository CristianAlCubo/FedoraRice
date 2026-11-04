# ── Calidad de vida de la terminal ───────────────────────────────────────────
# Cada integración se activa SOLO si el programa existe (nada falla si falta).
# Quitar todo: borrar la línea `source ~/.config/zsh/qol.zsh` de ~/.zshrc.

# Historial: sin duplicados al buscar, y los comandos que empiezan con espacio no se guardan
setopt hist_ignore_space hist_reduce_blanks hist_find_no_dups no_beep

# Sugerencias: del historial y, si no hay, del completado. Ctrl+Espacio las acepta.
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
bindkey '^ ' autosuggest-accept

# Ctrl+Z alterna entre el programa suspendido y la shell (como `fg`, pero con la misma tecla)
fancy-ctrl-z() { if [[ $#BUFFER -eq 0 ]]; then BUFFER="fg"; zle accept-line; else zle push-input; zle clear-screen; fi }
zle -N fancy-ctrl-z; bindkey '^Z' fancy-ctrl-z

# ── fzf: Ctrl+R historial difuso · Ctrl+T archivos · Alt+C carpetas (colores en fzf-theme.zsh, generado por rice-theme)
if (( $+commands[fzf] )); then
  [[ -r ~/.config/zsh/fzf-theme.zsh ]] && source ~/.config/zsh/fzf-theme.zsh
  (( $+commands[fd] )) && {
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
  }
  (( $+commands[bat] )) && export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {}'"
  (( $+commands[eza] )) && export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always --icons {} | head -60'"
  export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window=down:3:wrap"
  source <(fzf --zsh)
  # fkill: elige procesos y los termina · fbr: cambia de rama de git
  fkill() { local p; p=$(ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | sed 1d | fzf -m --header='Procesos (Tab marca varios)' | awk '{print $1}'); [[ -n $p ]] && echo $p | xargs kill ${1:--15}; }
  fbr()   { local b; b=$(git branch --all --color=never | sed 's/^[* ]*//; s#remotes/origin/##' | sort -u | fzf --header='Rama') && git switch "$b"; }
fi

# ── zoxide: `z proyecto` salta a la carpeta más usada que coincida · `zi` elige con fzf
(( $+commands[zoxide] )) && eval "$(zoxide init zsh --cmd z)"

# ── eza en lugar de ls (iconos, carpetas primero, árbol con `lt`)
if (( $+commands[eza] )); then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -lh --icons --group-directories-first --git'
  alias la='eza -lAh --icons --group-directories-first --git'
  alias lt='eza --tree --level=2 --icons --group-directories-first'
fi

# ── bat: páginas man y diffs con color (tema "ansi": sigue la paleta del terminal, o sea, tu tema)
if (( $+commands[bat] )); then
  export BAT_THEME=ansi
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
  export MANROFFOPT="-c"
fi

# ── delta (diffs de git bonitos) y utilidades
(( $+commands[lazygit] )) && alias lg='lazygit'
(( $+commands[tldr] ))    && alias help='tldr'
(( $+commands[duf] ))     && alias df='duf'

# ── Atajos varios
mkcd()  { mkdir -p -- "$1" && cd -- "$1"; }
x()     { case "$1" in *.tar.bz2|*.tbz2) tar xjf "$1";; *.tar.gz|*.tgz) tar xzf "$1";; *.tar.xz) tar xJf "$1";; *.tar.zst) tar --zstd -xf "$1";; *.tar) tar xf "$1";; *.zip) unzip "$1";; *.7z) 7z x "$1";; *.rar) unrar x "$1";; *.gz) gunzip "$1";; *.xz) unxz "$1";; *) echo "x: formato no reconocido: $1";; esac; }
alias reload='exec zsh'
alias ports='ss -tulpn'
alias serve='python3 -m http.server 8000'
