#!/usr/bin/env bash

macarchy_apply_raycast() {
    local bundle_id="com.raycast.macos"
    local defaults_bin="${MACARCHY_DEFAULTS_BIN:-}"
    local raycast_app="${MACARCHY_RAYCAST_APP:-/Applications/Raycast.app}"
    local preferences="$HOME/Library/Preferences/$bundle_id.plist"
    local current_theme="bundled-raycast-light"

    [[ "$(uname -s)" == "Darwin" ]] || return 0
    [[ -d "$raycast_app" || -f "$preferences" ]] || return 0
    [[ -n "$defaults_bin" ]] || defaults_bin="$(macarchy_command defaults || true)"
    [[ -n "$defaults_bin" ]] || return 0
    [[ "$THEME_DARK_MODE" == "true" ]] && current_theme="bundled-raycast-dark"

    "$defaults_bin" write "$bundle_id" raycastShouldFollowSystemAppearance -bool true &&
        "$defaults_bin" write "$bundle_id" raycastCurrentThemeId -string "$current_theme" &&
        "$defaults_bin" write "$bundle_id" raycastCurrentThemeIdDarkAppearance -string bundled-raycast-dark &&
        "$defaults_bin" write "$bundle_id" raycastCurrentThemeIdLightAppearance -string bundled-raycast-light || {
            macarchy_error "Raycast appearance defaults could not be updated"
            return 1
        }

    macarchy_info "  Raycast: $current_theme"
}
