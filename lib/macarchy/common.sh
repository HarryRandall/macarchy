#!/usr/bin/env bash

MACARCHY_CONFIG_HOME="${MACARCHY_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}}"
MACARCHY_DATA_HOME="${MACARCHY_DATA_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}}"
MACARCHY_STATE_HOME="${MACARCHY_STATE_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}}"
MACARCHY_CACHE_HOME="${MACARCHY_CACHE_HOME:-${XDG_CACHE_HOME:-$HOME/.cache}}"
MACARCHY_GENERATED_DIR="${MACARCHY_GENERATED_DIR:-$MACARCHY_CONFIG_HOME/macarchy/generated}"
MACARCHY_GENERATED_MANIFEST="${MACARCHY_GENERATED_MANIFEST:-$MACARCHY_STATE_HOME/macarchy/generated/themes.tsv}"

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
# partially written configuration behind. Generated files are private to the
# current user and should not follow a pre-existing symlink unexpectedly.
macarchy_atomic_write() {
    local target="$1"
    local mode="${2:-600}"
    local directory temporary

    directory="$(dirname "$target")"
    if [[ -L "$target" || -d "$target" ]]; then
        macarchy_error "refusing to replace non-file path: $target"
        return 1
    fi
    mkdir -p "$directory" || {
        macarchy_error "could not create directory: $directory"
        return 1
    }
    temporary="$(mktemp "$directory/.macarchy.XXXXXX")" || {
        macarchy_error "could not create a temporary file in $directory"
        return 1
    }
    if ! cat > "$temporary"; then
        rm -f "$temporary"
        macarchy_error "could not write temporary file for $target"
        return 1
    fi
    if ! chmod "$mode" "$temporary" || ! mv "$temporary" "$target"; then
        rm -f "$temporary"
        macarchy_error "could not replace $target"
        return 1
    fi
}

macarchy_file_hash() {
    local file="$1"
    local output checksum

    if command -v shasum >/dev/null 2>&1; then
        output="$(shasum -a 256 < "$file")" || {
            macarchy_error "could not checksum generated file: $file"
            return 1
        }
    elif command -v sha256sum >/dev/null 2>&1; then
        output="$(sha256sum < "$file")" || {
            macarchy_error "could not checksum generated file: $file"
            return 1
        }
    else
        macarchy_error "shasum or sha256sum is required to track generated files"
        return 1
    fi

    checksum="${output%% *}"
    [[ "$checksum" =~ ^[0-9A-Fa-f]{64}$ ]] || {
        macarchy_error "checksum command returned invalid output for $file"
        return 1
    }
    printf '%s\n' "$checksum"
}

# Keep a checksum beside every generated file. The installer uses this list to
# remove Macarchy-owned output while preserving anything the user later edits.
macarchy_record_generated_file() {
    local target="$1"
    local checksum manifest_dir temporary current current_checksum

    [[ -f "$target" && ! -L "$target" ]] || {
        macarchy_error "cannot record missing generated file: $target"
        return 1
    }
    case "$target" in
        *$'\t'*|*$'\n'*)
            macarchy_error "generated file path contains a tab or newline: $target"
            return 1
            ;;
    esac

    checksum="$(macarchy_file_hash "$target")" || return 1
    manifest_dir="$(dirname "$MACARCHY_GENERATED_MANIFEST")"
    mkdir -p "$manifest_dir" || {
        macarchy_error "could not create generated-file state directory: $manifest_dir"
        return 1
    }
    temporary="$(mktemp "$manifest_dir/.themes.XXXXXX")" || {
        macarchy_error "could not create generated-file manifest"
        return 1
    }

    if [[ -L "$MACARCHY_GENERATED_MANIFEST" ]]; then
        rm -f "$temporary"
        macarchy_error "generated-file manifest must not be a symlink"
        return 1
    elif [[ -f "$MACARCHY_GENERATED_MANIFEST" ]]; then
        if [[ ! -r "$MACARCHY_GENERATED_MANIFEST" ]]; then
            rm -f "$temporary"
            macarchy_error "generated-file manifest is not readable"
            return 1
        fi
        while IFS=$'\t' read -r current current_checksum; do
            [[ -n "$current" ]] || continue
            [[ "$current" == "$target" ]] && continue
            printf '%s\t%s\n' "$current" "$current_checksum" >> "$temporary" || {
                rm -f "$temporary"
                return 1
            }
        done < "$MACARCHY_GENERATED_MANIFEST"
    elif [[ -e "$MACARCHY_GENERATED_MANIFEST" ]]; then
        rm -f "$temporary"
        macarchy_error "generated-file manifest is not a regular file"
        return 1
    fi

    printf '%s\t%s\n' "$target" "$checksum" >> "$temporary" || {
        rm -f "$temporary"
        return 1
    }
    if ! macarchy_atomic_write "$MACARCHY_GENERATED_MANIFEST" < "$temporary"; then
        rm -f "$temporary"
        return 1
    fi
    rm -f "$temporary"
}

macarchy_write_generated() {
    local target="$1"
    local mode="${2:-600}"

    macarchy_atomic_write "$target" "$mode" || return 1
    macarchy_record_generated_file "$target"
}

macarchy_trim() {
    printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}
