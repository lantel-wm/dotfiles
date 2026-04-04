# profile zshrc

setopt HIST_IGNORE_ALL_DUPS
HISTSIZE=50000
SAVEHIST=50000

bindkey -e
WORDCHARS=${WORDCHARS//[\/]}

ZSH_AUTOSUGGEST_MANUAL_REBIND=1
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)

path_prepend_if_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  case ":$PATH:" in
    *":$dir:"*) ;;
    *) export PATH="$dir:$PATH" ;;
  esac
}

ZIM_HOME=${ZDOTDIR:-${HOME}}/.zim
if [[ ! -e ${ZIM_HOME}/zimfw.zsh ]]; then
  if (( ${+commands[curl]} )); then
    curl -fsSL --create-dirs -o ${ZIM_HOME}/zimfw.zsh \
      https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
  else
    mkdir -p ${ZIM_HOME} && wget -nv -O ${ZIM_HOME}/zimfw.zsh \
      https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
  fi
fi

if [[ ! ${ZIM_HOME}/init.zsh -nt ${ZIM_CONFIG_FILE:-${ZDOTDIR:-${HOME}}/.zimrc} ]]; then
  source ${ZIM_HOME}/zimfw.zsh init
fi
source ${ZIM_HOME}/init.zsh

autoload -Uz compinit
ZSH_COMPDUMP="${ZDOTDIR:-$HOME}/.zcompdump"
if [[ -f "$ZSH_COMPDUMP" ]]; then
  compinit -C -d "$ZSH_COMPDUMP"
else
  compinit -d "$ZSH_COMPDUMP"
fi

zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

zmodload -F zsh/terminfo +p:terminfo
for key ('^[[A' '^P' ${terminfo[kcuu1]}) bindkey ${key} history-substring-search-up
for key ('^[[B' '^N' ${terminfo[kcud1]}) bindkey ${key} history-substring-search-down
for key ('k') bindkey -M vicmd ${key} history-substring-search-up
for key ('j') bindkey -M vicmd ${key} history-substring-search-down
unset key

CONDA_ROOT="${CONDA_ROOT:-$HOME/miniconda3}"
if [[ -d "$CONDA_ROOT" ]]; then
  path_prepend_if_dir "$CONDA_ROOT/condabin"

  _conda_lazy_init() {
    unset -f conda
    if [[ -r "$CONDA_ROOT/etc/profile.d/conda.sh" ]]; then
      source "$CONDA_ROOT/etc/profile.d/conda.sh"
    fi
    conda "$@"
  }

  conda() {
    _conda_lazy_init "$@"
  }
fi

y() {
  local tmp cwd
  tmp="$(mktemp -t "yazi-cwd.XXXXXX")" || return 1
  yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd < "$tmp"
  [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
  rm -f -- "$tmp"
}

export NVM_DIR="$HOME/.nvm"

_lazy_load_nvm() {
  unset -f nvm node npm npx
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
}

nvm() {
  _lazy_load_nvm
  nvm "$@"
}

node() {
  _lazy_load_nvm
  node "$@"
}

npm() {
  _lazy_load_nvm
  npm "$@"
}

npx() {
  _lazy_load_nvm
  npx "$@"
}

fh() {
  emulate -L zsh
  setopt pipefail no_aliases

  (( $+commands[fzf] )) || { print -u2 -- "fzf not found in PATH"; return 127; }
  (( $+commands[bat] )) || { print -u2 -- "bat not found in PATH"; return 127; }

  local query selected tmp_display tmp_colored idx raw display
  local -A seen
  local -a entries displays histnos items colored_lines fzf_args

  query="${LBUFFER-}"
  if [[ -n $query ]]; then
    query=${query//\\/\\\\}
    query=${query//\'/\\\'}
    query=${query//!/\\!}
    query=${query//|/\\|}
    query=${query//^/\\^}
    query=${query//\$/\\$}
    query=${query// /\\ }
    query=${query//#/^}
  fi

  for idx in ${(Onk)history}; do
    raw=${history[$idx]}
    [[ -n ${seen[$raw]} ]] && continue
    seen[$raw]=1
    entries+=("$raw")
    histnos+=("$idx")

    display=${raw//$'\r'/ }
    display=${display//$'\n'/ }
    display=${display//$'\t'/ }
    while [[ $display == *"  "* ]]; do
      display=${display//  / }
    done
    display=${display## }
    display=${display%% }
    displays+=("$display")
  done

  (( ${#displays} > 0 )) || return 1

  tmp_display="$(mktemp "${TMPDIR:-/tmp}/fh-display.XXXXXX")" || return 1
  tmp_colored="$(mktemp "${TMPDIR:-/tmp}/fh-colored.XXXXXX")" || {
    rm -f -- "$tmp_display"
    return 1
  }

  printf '%s\n' "${displays[@]}" >"$tmp_display"
  bat --language=sh --color=always --style=plain --paging=never "$tmp_display" >"$tmp_colored" || {
    rm -f -- "$tmp_display" "$tmp_colored"
    return 1
  }
  colored_lines=("${(@f)$(<"$tmp_colored")}")
  rm -f -- "$tmp_display" "$tmp_colored"

  for (( idx = 1; idx <= ${#entries}; idx++ )); do
    items+=("$idx"$'\t'"${histnos[idx]}"$'\t'"${colored_lines[idx]}")
  done

  fzf_args=(
    --ansi
    --scheme=history
    --delimiter=$'\t'
    --with-nth=2,3..
  )
  [[ -n $query ]] && fzf_args+=(--query="$query")

  selected="$(printf '%s\n' "${items[@]}" | fzf "${fzf_args[@]}")" || return
  idx=${selected%%$'\t'*}
  [[ $idx == <-> ]] || return 1

  print -z -- "${entries[idx]}"
}

unalias fzj 2>/dev/null
fzj() {
  emulate -L zsh
  setopt pipefail no_aliases

  (( $+commands[fzf] )) || { print -u2 -- "fzf not found in PATH"; return 127; }
  (( $+commands[jq] )) || { print -u2 -- "jq not found in PATH"; return 127; }

  local zellij_bin sessions selected rc
  if [[ -n "${ZELLIJ_BIN:-}" && -x "${ZELLIJ_BIN}" ]]; then
    zellij_bin="${ZELLIJ_BIN}"
  elif [[ -n "${commands[zellij]:-}" && -x "${commands[zellij]}" ]]; then
    zellij_bin="${commands[zellij]}"
  else
    print -u2 -- "zellij binary not found; set ZELLIJ_BIN or install zellij"
    return 127
  fi
  local -x ZELLIJ_BIN_FZJ="${zellij_bin}"

  sessions="$("${zellij_bin}" list-sessions --short --no-formatting 2>/dev/null)"
  rc=$?
  (( rc == 0 )) || { print -u2 -- "failed to list zellij sessions"; return $rc; }
  [[ -n $sessions ]] || { print -u2 -- "no active zellij sessions"; return 1; }

  selected="$(
    print -r -- "$sessions" |
      fzf \
        --ansi \
        --prompt='zellij session > ' \
        --height='80%' \
        --layout='reverse' \
        --cycle \
        --border \
        --preview-window='right,70%,border-left' \
        --preview '
          session={}
          "$ZELLIJ_BIN_FZJ" list-sessions 2>/dev/null |
            awk -v name="$session" '"'"'index($0, name) { print; exit }'"'"'
          clients="$("$ZELLIJ_BIN_FZJ" --session "$session" action list-clients 2>/dev/null | awk "NR > 1 && NF { count++ } END { print count + 0 }")"
          printf "\033[1;33mClients:\033[0m %s\n" "$clients"
          "$ZELLIJ_BIN_FZJ" --session "$session" action list-panes --json --all 2>/dev/null |
            jq -r '"'"'
              map(select((.is_plugin | not) and .is_selectable and (.exited | not)))
              | sort_by([
                  (if .is_floating then 1 else 0 end),
                  (if .is_suppressed then 1 else 0 end),
                  -((.pane_content_rows // 0) * (.pane_content_columns // 0)),
                  (.tab_position // 9999),
                  (.id // 9999)
                ])
              | .[0]?
              | if . then
                  (if .pane_cwd then "\u001b[1;36mCwd:\u001b[0m \(.pane_cwd)" else empty end)
                else
                  "\u001b[2mNo previewable terminal pane found.\u001b[0m"
                end
            '"'"'
        '
  )"
  rc=$?
  (( rc == 0 )) && [[ -n $selected ]] || return $rc

  if [[ -n ${ZELLIJ:-} ]]; then
    "${zellij_bin}" action switch-session -- "$selected"
  else
    "${zellij_bin}" attach -- "$selected" 2> >(grep -Fvx "Bye from Zellij!" >&2)
    printf '\033[1A\r\033[2K\r'
  fi
}

frg() {
  local query line file lineno
  (( $+commands[rg] )) || { print -u2 -- "rg not found in PATH"; return 127; }
  (( $+commands[fzf] )) || { print -u2 -- "fzf not found in PATH"; return 127; }
  (( $+commands[bat] )) || { print -u2 -- "bat not found in PATH"; return 127; }
  query="${1:-.}"

  line=$(
    rg --line-number --no-heading "$query" | \
      fzf --delimiter : \
        --preview '
          file={1}
          lineno={2}
          start=$((lineno>20 ? lineno-20 : 1))
          end=$((lineno+20))
          bat --style=plain --color=always \
              --line-range "${start}:${end}" \
              --highlight-line "${lineno}" \
              "$file"
        '
  ) || return

  file=$(printf '%s\n' "$line" | cut -d: -f1)
  lineno=$(printf '%s\n' "$line" | cut -d: -f2)
  hx "+${lineno}" "$file"
}

ff() {
  local file
  (( $+commands[fd] )) || { print -u2 -- "fd not found in PATH"; return 127; }
  (( $+commands[fzf] )) || { print -u2 -- "fzf not found in PATH"; return 127; }
  (( $+commands[bat] )) || { print -u2 -- "bat not found in PATH"; return 127; }
  file=$(
    fd . |
      fzf \
        --query="${1:-}" \
        --preview 'bat --style=plain --color=always {}'
  ) || return

  hx "$file"
}

if [ -r "$HOME/.local/bin/env" ]; then
  . "$HOME/.local/bin/env"
fi

if [ -r "$HOME/.config/zsh/local.zsh" ]; then
  . "$HOME/.config/zsh/local.zsh"
fi

(( $+commands[lazygit] )) && alias lg='lazygit'
(( $+commands[hx] )) && alias vi='hx'

if (( $+commands[eza] )); then
  alias ls='eza'
  alias ll='eza -lh --group-directories-first --icons --hyperlink'
  alias la='ll -a'
  alias lt='eza --tree --level=2 --long --icons --git'
  alias lta='lt -a'
fi

if [[ -n "${ZELLIJ_BIN:-}" && -x "${ZELLIJ_BIN}" ]]; then
  alias tmux="${ZELLIJ_BIN}"
elif (( $+commands[zellij] )); then
  alias tmux='zellij'
fi

(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"

if [[ -x "${ZELLIJ_BIN}" ]]; then
  unalias zellij 2>/dev/null
  unfunction zellij 2>/dev/null
  zellij() {
    "$ZELLIJ_BIN" "$@"
  }
  alias tmux="zellij"
fi
