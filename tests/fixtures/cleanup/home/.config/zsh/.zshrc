# Fast zsh startup. Keep the first prompt cheap; initialize completion on first Tab.
setopt PROMPT_SUBST

_MACARCHY_SHELL_ENV="$HOME/.config/macarchy/generated/shell-env"
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
