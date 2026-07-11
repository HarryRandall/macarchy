#!/usr/bin/env bash

MACARCHY_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
MACARCHY_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
MACARCHY_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
MACARCHY_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

macarchy_info() {
    printf '%s\n' "$*"
}

macarchy_warn() {
    printf 'warning: %s\n' "$*" >&2
}

macarchy_error() {
    printf 'error: %s\n' "$*" >&2
}

macarchy_command() {
    command -v "$1" 2>/dev/null
}

# Write through a temporary file so an interrupted update cannot leave a
# partially written configuration behind.
macarchy_atomic_write() {
    local target="$1"
    local directory temporary

    directory="$(dirname "$target")"
    mkdir -p "$directory"
    temporary="$(mktemp "$directory/.macarchy.XXXXXX")"
    cat > "$temporary"
    chmod 600 "$temporary"
    mv "$temporary" "$target"
}

macarchy_trim() {
    printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}
