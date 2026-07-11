#!/usr/bin/env bash

macarchy_apply_ghostty() {
    local source_file="$MACARCHY_THEME_DIR/ghostty.conf"
    local config_dir="$MACARCHY_CONFIG_HOME/ghostty"
    local target_file="$config_dir/macarchy-theme.ghostty"

    [[ -f "$source_file" ]] || return 0
    [[ -f "$config_dir/config.ghostty" || -f "$config_dir/config" ]] || return 0
    macarchy_ghostty_theme_valid "$source_file" || {
        macarchy_error "theme '$MACARCHY_THEME_NAME' contains unsupported Ghostty settings"
        return 1
    }

    macarchy_atomic_write "$target_file" < "$source_file"
    pkill -USR2 -x ghostty >/dev/null 2>&1 || pkill -USR2 -x Ghostty >/dev/null 2>&1 || true
    macarchy_info "  Ghostty: colours updated"
}
