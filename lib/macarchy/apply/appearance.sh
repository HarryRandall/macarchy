#!/usr/bin/env bash

macarchy_apply_appearance() {
    [[ "$(uname -s)" == "Darwin" ]] || return 0
    if osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $THEME_DARK_MODE" >/dev/null 2>&1; then
        macarchy_info "  macOS appearance: $([[ "$THEME_DARK_MODE" == true ]] && printf 'dark' || printf 'light')"
    else
        macarchy_warn "macOS appearance could not be changed"
    fi
}

macarchy_apply_wallpaper() {
    local relative="$1"
    local setter

    [[ -n "$relative" ]] || { macarchy_info "  Wallpaper: skipped"; return 0; }
    setter="$(macarchy_command set-wallpaper || true)"
    [[ -n "$setter" && -x "$setter" ]] || setter="$MACARCHY_BIN_DIR/set-wallpaper"
    [[ -x "$setter" ]] || {
        macarchy_warn "set-wallpaper is not installed"
        return 0
    }

    if "$setter" "$MACARCHY_THEME_DIR/$relative"; then
        macarchy_info "  Wallpaper: $relative"
    else
        macarchy_error "wallpaper could not be changed"
        return 1
    fi
}
