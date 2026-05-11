# Aliases
alias ls "eza --icons"
alias treelist "tree -a -I '.git'"
alias n "nvim"
alias sail './vendor/bin/sail'

# Optional SSH shortcut examples:
# alias devbox 'ssh user@example-host'
# alias devbox_sftp 'sftp user@example-host'

# Keep processes running after closing the terminal
function stay
  nohup $argv > /dev/null 2>&1 < /dev/null & disown
end

# Disable Fish startup greeting
set fish_greeting

# Key bindings (vi mode + kj -> Esc)
function fish_user_key_bindings
  fish_vi_key_bindings
  bind -M insert -m default kj backward-char force-repaint
end

# Disable right prompt
# function fish_right_prompt
#   echo (set_color 71717a)"$USER"@(prompt_hostname)
# end

# Disable vi mode letter at start
functions -e fish_mode_prompt

# Cursor shape in vi mode
set -U fish_cursor_default block

# Custom prompt
function fish_prompt
    # Rainbow fish ><> (new colours each render)
    set colors red yellow green cyan blue magenta
    set_color $colors[(math (random) % (count $colors) + 1)]
    echo -n ">"
    set_color $colors[(math (random) % (count $colors) + 1)]
    echo -n "<"
    set_color $colors[(math (random) % (count $colors) + 1)]
    echo -n ">"
    set_color normal
    echo -n " "

    # Last directory only
    set_color --bold 06b6d4
    echo -n (basename $PWD)

    # Arrow
    echo -n " "
    set_color --bold 14b8a6
    echo -n "❯ "
    set_color normal
end

# Colour scheme
set -l foreground c0caf5
set -l selection 6366f1
set -l comment 737373
set -l red f7768e
set -l orange ff9e64
set -l yellow e0af68
set -l green 9ece6a
set -l purple 9d7cd8
set -l cyan 7dcfff
set -l pink bb9af7

set -g fish_color_normal $foreground
set -g fish_color_command $cyan
set -g fish_color_keyword $pink
set -g fish_color_quote $yellow
set -g fish_color_redirection $foreground
set -g fish_color_end $orange
set -g fish_color_error $red
set -g fish_color_param $purple
set -g fish_color_comment $comment
set -g fish_color_selection --background=$selection
set -g fish_color_search_match --background=$selection
set -g fish_color_operator $green
set -g fish_color_escape $pink
set -g fish_color_autosuggestion $comment
set -g fish_pager_color_progress $comment
set -g fish_pager_color_prefix $cyan
set -g fish_pager_color_completion $foreground
set -g fish_pager_color_description $comment
set -g fish_pager_color_selected_background --background=$selection

# Editor
set -x EDITOR nvim

# Homebrew path (Apple Silicon)
if test -x /opt/homebrew/bin/brew
    eval (/opt/homebrew/bin/brew shellenv)
end



# python alias
alias python python3
alias pip pip3

function weather
    if test -x "$HOME/.local/bin/weathr"
        "$HOME/.local/bin/weathr" $argv
    else
        echo "weathr is not installed" >&2
        return 1
    end
end
