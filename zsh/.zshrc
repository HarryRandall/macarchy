# Fast zsh startup. Keep the first prompt cheap; initialize completion on first Tab.
setopt PROMPT_SUBST

_MACARCHY_SHELL_ENV="$HOME/.config/themes/.shell-env"
function _macarchy_load_env() {
    [[ -r "$_MACARCHY_SHELL_ENV" ]] && source "$_MACARCHY_SHELL_ENV"
}

_macarchy_load_env
PROMPT='%B%F{${MACARCHY_ACCENT_IDX:-7}}%1~%f%b %B%F{${MACARCHY_FG_IDX:-15}}❯%f%b '
RPROMPT=''

bindkey -v
KEYTIMEOUT=1

autoload -Uz add-zsh-hook compinit
add-zsh-hook precmd _macarchy_load_env
add-zsh-hook preexec _macarchy_load_env

# Make tab completion case-insensitive, so "d<Tab>" can match "Desktop".
zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}'

typeset -g _LAZY_COMPINIT_DONE=0

function _bind_tab_widget() {
    bindkey '^I' tab_accept_or_complete
    bindkey -M emacs '^I' tab_accept_or_complete
    bindkey -M viins '^I' tab_accept_or_complete
}

function _lazy_compinit() {
    (( _LAZY_COMPINIT_DONE )) && return

    local compdump="${ZDOTDIR:-$HOME}/.zcompdump-${HOST%%.*}-${ZSH_VERSION}"

    compinit -C -d "$compdump"
    _LAZY_COMPINIT_DONE=1
    _bind_tab_widget
}

function tab_accept_or_complete() {
    if [[ -n "${POSTDISPLAY-}" ]] && zle -l autosuggest-accept >/dev/null 2>&1; then
        zle autosuggest-accept
        return
    fi

    _lazy_compinit
    zle complete-word
}

zle -N tab_accept_or_complete
_bind_tab_widget

# Editor
export EDITOR=nvim

# History in ZDOTDIR
HISTFILE="$ZDOTDIR/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt AUTO_CD HIST_IGNORE_DUPS HIST_IGNORE_SPACE INTERACTIVE_COMMENTS SHARE_HISTORY

# Aliases
alias ls='eza --icons'
alias treelist='tree -a -I .git'
alias n='nvim'
alias python='python3'
alias pip='pip3'

# Functions
function stay() {
    nohup "$@" > /dev/null 2>&1 < /dev/null &
    disown
}

function weather() {
    if [[ -x "$HOME/.local/bin/weathr" ]]; then
        "$HOME/.local/bin/weathr" "$@"
    elif [[ -x "/opt/homebrew/bin/weathr" ]]; then
        /opt/homebrew/bin/weathr "$@"
    else
        echo "weathr is not installed" >&2
        return 1
    fi
}

# AI account switcher wrappers (must come before PATH below; sets ~/bin first)
[[ -r "$HOME/.config/zsh/zshrc.d/ai-account-switchers.zsh" ]] && source "$HOME/.config/zsh/zshrc.d/ai-account-switchers.zsh"

# PATH
typeset -gU path fpath
path=(
    "$HOME/.config/composer/vendor/bin"
    "$HOME/.composer/vendor/bin"
    "$HOME/.local/bin"
    /opt/homebrew/bin
    /opt/homebrew/sbin
    /usr/local/bin
    /usr/bin
    /bin
    /usr/sbin
    /sbin
    $path
)
fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
export PATH
export FPATH

[[ -r "$HOME/.config/oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && source "$HOME/.config/oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"

# Keep syntax highlighting last so it can wrap final widgets.
[[ -r "$HOME/.config/oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && source "$HOME/.config/oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
