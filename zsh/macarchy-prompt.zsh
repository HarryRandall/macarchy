setopt PROMPT_SUBST

_MACARCHY_SHELL_ENV="${XDG_CONFIG_HOME:-$HOME/.config}/themes/.shell-env"

function _macarchy_load_theme() {
    [[ -r "$_MACARCHY_SHELL_ENV" ]] && source "$_MACARCHY_SHELL_ENV"
}

_macarchy_load_theme
autoload -Uz add-zsh-hook
add-zsh-hook precmd _macarchy_load_theme

# Indexed colours update when Ghostty reloads its palette. True-colour values
# would remain fixed in existing terminal cells.
PROMPT='%B%F{${MACARCHY_ACCENT_IDX:-7}}%1~%f%b %B%F{${MACARCHY_FG_IDX:-15}}❯%f%b '
RPROMPT=''
