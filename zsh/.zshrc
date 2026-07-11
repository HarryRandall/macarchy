# Macarchy's shell setup is deliberately small. Put machine-specific settings
# in local.zsh so updates do not overwrite them.
[[ -r "$ZDOTDIR/macarchy-prompt.zsh" ]] && source "$ZDOTDIR/macarchy-prompt.zsh"

bindkey -v
KEYTIMEOUT=1

autoload -Uz add-zsh-hook compinit
zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}'

typeset -g _MACARCHY_COMPINIT_DONE=0

function _macarchy_complete_word() {
    if (( ! _MACARCHY_COMPINIT_DONE )); then
        local compdump="${ZDOTDIR:-$HOME}/.zcompdump-${HOST%%.*}-${ZSH_VERSION}"
        compinit -C -d "$compdump"
        _MACARCHY_COMPINIT_DONE=1
    fi
    zle complete-word
}

zle -N _macarchy_complete_word
bindkey '^I' _macarchy_complete_word
bindkey -M viins '^I' _macarchy_complete_word

if [[ -z "${EDITOR:-}" ]]; then
    if command -v nvim >/dev/null 2>&1; then
        EDITOR=nvim
    else
        EDITOR=vi
    fi
fi
export EDITOR

HISTFILE="$ZDOTDIR/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt AUTO_CD HIST_IGNORE_DUPS HIST_IGNORE_SPACE INTERACTIVE_COMMENTS SHARE_HISTORY

if command -v eza >/dev/null 2>&1; then
    alias ls='eza --icons'
fi
command -v nvim >/dev/null 2>&1 && alias n='nvim'

function stay() {
    nohup "$@" >/dev/null 2>&1 </dev/null &
    disown
}

typeset -gU path fpath
path=("$HOME/.local/bin" $path)
export PATH FPATH

[[ -r "$ZDOTDIR/local.zsh" ]] && source "$ZDOTDIR/local.zsh"
