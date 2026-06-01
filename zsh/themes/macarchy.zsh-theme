# macarchy.zsh-theme
#
# Uses ANSI palette indices (%F{N}) so the prompt re-resolves against the
# active ghostty palette on every render — meaning theme-switch's ghostty
# config reload (SIGUSR2) repaints existing scrollback prompts as well as
# new ones. Truecolor (%F{#hex}) would be baked into the cell buffer.
#
# Indices come from ~/.config/themes/.shell-env (written by theme-switch):
#   MACARCHY_ACCENT_IDX -> directory text (e.g. palette 2 on awakening = yellow)
#   MACARCHY_FG_IDX     -> arrow + path text (15 in dark mode, 0 in light)

setopt PROMPT_SUBST

_MACARCHY_SHELL_ENV="$HOME/.config/themes/.shell-env"

_macarchy_load_env() {
    [[ -r "$_MACARCHY_SHELL_ENV" ]] && source "$_MACARCHY_SHELL_ENV"
}

# Load once at theme init so the very first prompt has the right indices.
_macarchy_load_env

# PROMPT_SUBST expands ${...} at each render, so when .shell-env is
# re-sourced (precmd / preexec) the next prompt picks up the new indices.
PROMPT='%B%F{${MACARCHY_ACCENT_IDX:-7}}%1~%f%b %B%F{${MACARCHY_FG_IDX:-15}}❯%f%b '
RPROMPT=''

autoload -Uz add-zsh-hook
add-zsh-hook precmd  _macarchy_load_env
add-zsh-hook preexec _macarchy_load_env
