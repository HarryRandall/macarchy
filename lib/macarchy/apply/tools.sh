#!/usr/bin/env bash

macarchy_apply_neovim() {
    local config_dir="$MACARCHY_CONFIG_HOME/nvim"
    local state_file="$MACARCHY_THEMES_DIR/.nvim-colorscheme"

    [[ -n "$THEME_NVIM_COLORSCHEME" && -d "$config_dir" ]] || return 0
    printf '%s\n' "$THEME_NVIM_COLORSCHEME" | macarchy_atomic_write "$state_file"
    pkill -WINCH -x nvim >/dev/null 2>&1 || true
    macarchy_info "  Neovim: $THEME_NVIM_COLORSCHEME"
}

macarchy_write_btop_theme() {
    local ghostty_file="$MACARCHY_THEME_DIR/ghostty.conf"
    local target="$MACARCHY_CONFIG_HOME/btop/themes/macarchy.theme"
    local background foreground selection accent muted green yellow red cyan purple orange

    background="$(macarchy_ghostty_colour "$ghostty_file" background '#000000')"
    foreground="$(macarchy_ghostty_colour "$ghostty_file" foreground '#ffffff')"
    selection="$(macarchy_ghostty_colour "$ghostty_file" selection-background "$background")"
    accent="$(macarchy_ghostty_palette "$ghostty_file" 4 "$foreground")"
    muted="$(macarchy_ghostty_palette "$ghostty_file" 8 "$foreground")"
    green="$(macarchy_ghostty_palette "$ghostty_file" 2 "$accent")"
    yellow="$(macarchy_ghostty_palette "$ghostty_file" 3 "$accent")"
    red="$(macarchy_ghostty_palette "$ghostty_file" 1 "$accent")"
    cyan="$(macarchy_ghostty_palette "$ghostty_file" 6 "$accent")"
    purple="$(macarchy_ghostty_palette "$ghostty_file" 5 "$accent")"
    orange="$(macarchy_ghostty_palette "$ghostty_file" 11 "$yellow")"

    macarchy_atomic_write "$target" <<EOF
theme[main_bg]=""
theme[main_fg]="$foreground"
theme[title]="$foreground"
theme[hi_fg]="$accent"
theme[selected_bg]="$selection"
theme[selected_fg]="$foreground"
theme[inactive_fg]="$muted"
theme[proc_misc]="$cyan"
theme[cpu_box]="$muted"
theme[mem_box]="$muted"
theme[net_box]="$muted"
theme[proc_box]="$muted"
theme[div_line]="$muted"
theme[temp_start]="$green"
theme[temp_mid]="$yellow"
theme[temp_end]="$red"
theme[cpu_start]="$green"
theme[cpu_mid]="$yellow"
theme[cpu_end]="$red"
theme[free_start]="$green"
theme[free_mid]="$cyan"
theme[free_end]="$accent"
theme[cached_start]="$cyan"
theme[cached_mid]="$accent"
theme[cached_end]="$purple"
theme[available_start]="$green"
theme[available_mid]="$yellow"
theme[available_end]="$orange"
theme[used_start]="$yellow"
theme[used_mid]="$orange"
theme[used_end]="$red"
theme[download_start]="$accent"
theme[download_mid]="$cyan"
theme[download_end]="$green"
theme[upload_start]="$yellow"
theme[upload_mid]="$orange"
theme[upload_end]="$red"
theme[process_start]="$green"
theme[process_mid]="$yellow"
theme[process_end]="$red"
EOF
}

macarchy_apply_btop() {
    local config="$MACARCHY_CONFIG_HOME/btop/btop.conf"
    local temporary

    [[ -f "$config" ]] || return 0
    macarchy_write_btop_theme
    temporary="$(mktemp "$(dirname "$config")/.btop.XXXXXX")"
    awk '
        /^color_theme[[:space:]]*=/ { print "color_theme = \"macarchy\""; found=1; next }
        { print }
        END { if (!found) print "color_theme = \"macarchy\"" }
    ' "$config" > "$temporary"
    mv "$temporary" "$config"
    pkill -USR2 -x btop >/dev/null 2>&1 || true
    macarchy_info "  btop: colours updated"
}
