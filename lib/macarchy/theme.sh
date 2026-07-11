#!/usr/bin/env bash

MACARCHY_THEMES_DIR="${MACARCHY_THEMES_DIR:-$MACARCHY_CONFIG_HOME/themes}"
MACARCHY_THEME_STATE="$MACARCHY_THEMES_DIR/.current"
MACARCHY_BACKGROUND_STATE="$MACARCHY_THEMES_DIR/.backgrounds.json"

macarchy_theme_reset() {
    THEME_DARK_MODE="true"
    THEME_WALLPAPER=""
    THEME_NVIM_COLORSCHEME=""
    THEME_BORDER_ACTIVE="0xfff2fcff"
    THEME_BORDER_INACTIVE="0x00000000"
    THEME_BORDER_WIDTH="6.0"
    THEME_SKETCHYBAR_BAR_COLOR="0x00000000"
    THEME_SKETCHYBAR_TEXT_COLOR="0xffffffff"
}

macarchy_theme_unquote() {
    local value="$1"
    case "$value" in
        \"*\") value="${value#\"}"; value="${value%\"}" ;;
        \'*\') value="${value#\'}"; value="${value%\'}" ;;
    esac
    printf '%s\n' "$value"
}

macarchy_theme_assign() {
    local key="$1"
    local value="$2"

    case "$key" in
        DARK_MODE) THEME_DARK_MODE="$value" ;;
        WALLPAPER) THEME_WALLPAPER="$value" ;;
        NVIM_COLORSCHEME) THEME_NVIM_COLORSCHEME="$value" ;;
        BORDER_ACTIVE) THEME_BORDER_ACTIVE="$value" ;;
        BORDER_INACTIVE) THEME_BORDER_INACTIVE="$value" ;;
        BORDER_WIDTH) THEME_BORDER_WIDTH="$value" ;;
        SKETCHYBAR_BAR_COLOR) THEME_SKETCHYBAR_BAR_COLOR="$value" ;;
        SKETCHYBAR_TEXT_COLOR) THEME_SKETCHYBAR_TEXT_COLOR="$value" ;;
        *)
            macarchy_error "unsupported key '$key' in theme.env"
            return 1
            ;;
    esac
}

macarchy_theme_validate() {
    case "$THEME_DARK_MODE" in true|false) ;; *) macarchy_error "DARK_MODE must be true or false"; return 1 ;; esac
    [[ "$THEME_WALLPAPER" != /* && "$THEME_WALLPAPER" != *".."* ]] || {
        macarchy_error "WALLPAPER must be a path inside the theme"
        return 1
    }
    [[ -z "$THEME_NVIM_COLORSCHEME" || "$THEME_NVIM_COLORSCHEME" =~ ^[A-Za-z0-9._-]+$ ]] || {
        macarchy_error "invalid NVIM_COLORSCHEME"
        return 1
    }
    [[ "$THEME_BORDER_ACTIVE" =~ ^0x[0-9A-Fa-f]{8}$ ]] || return 1
    [[ "$THEME_BORDER_INACTIVE" =~ ^0x[0-9A-Fa-f]{8}$ ]] || return 1
    [[ "$THEME_BORDER_WIDTH" =~ ^[0-9]+([.][0-9]+)?$ ]] || return 1
    [[ "$THEME_SKETCHYBAR_BAR_COLOR" =~ ^0x[0-9A-Fa-f]{8}$ ]] || return 1
    [[ "$THEME_SKETCHYBAR_TEXT_COLOR" =~ ^0x[0-9A-Fa-f]{8}$ ]] || return 1
}

# theme.env is parsed as data. It is never sourced, so a downloaded theme
# cannot execute shell commands during validation or application.
macarchy_theme_load() {
    local name="$1"
    local line key value

    MACARCHY_THEME_NAME="$name"
    MACARCHY_THEME_DIR="$MACARCHY_THEMES_DIR/$name"
    MACARCHY_THEME_FILE="$MACARCHY_THEME_DIR/theme.env"

    [[ -d "$MACARCHY_THEME_DIR" ]] || {
        macarchy_error "theme '$name' was not found in $MACARCHY_THEMES_DIR"
        return 1
    }
    [[ -f "$MACARCHY_THEME_FILE" ]] || {
        macarchy_error "theme '$name' has no theme.env"
        return 1
    }

    macarchy_theme_reset
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="$(macarchy_trim "$line")"
        [[ -z "$line" || "$line" == \#* ]] && continue
        [[ "$line" == *=* ]] || {
            macarchy_error "invalid line in $MACARCHY_THEME_FILE: $line"
            return 1
        }
        key="$(macarchy_trim "${line%%=*}")"
        value="$(macarchy_trim "${line#*=}")"
        value="$(macarchy_theme_unquote "$value")"
        macarchy_theme_assign "$key" "$value" || return 1
    done < "$MACARCHY_THEME_FILE"

    macarchy_theme_validate || {
        macarchy_error "theme '$name' contains an invalid value"
        return 1
    }
}

macarchy_theme_list() {
    local directory

    [[ -d "$MACARCHY_THEMES_DIR" ]] || return 0
    for directory in "$MACARCHY_THEMES_DIR"/*; do
        [[ -d "$directory" && -f "$directory/theme.env" ]] || continue
        basename "$directory"
    done | LC_ALL=C sort
}

macarchy_theme_current() {
    [[ -r "$MACARCHY_THEME_STATE" ]] && sed -n '1p' "$MACARCHY_THEME_STATE"
}

macarchy_theme_cycle() {
    local direction="$1"
    local current index target
    local -a themes=()

    while IFS= read -r target; do
        [[ -n "$target" ]] && themes+=("$target")
    done < <(macarchy_theme_list)
    (( ${#themes[@]} > 0 )) || {
        macarchy_error "no themes were found in $MACARCHY_THEMES_DIR"
        return 1
    }

    current="$(macarchy_theme_current)"
    for index in "${!themes[@]}"; do
        [[ "${themes[$index]}" == "$current" ]] || continue
        if [[ "$direction" == "prev" ]]; then
            printf '%s\n' "${themes[$(((index - 1 + ${#themes[@]}) % ${#themes[@]}))]}"
        else
            printf '%s\n' "${themes[$(((index + 1) % ${#themes[@]}))]}"
        fi
        return 0
    done

    [[ "$direction" == "prev" ]] && target="${themes[${#themes[@]}-1]}" || target="${themes[0]}"
    printf '%s\n' "$target"
}

macarchy_theme_background_valid() {
    local relative="$1"
    [[ -n "$relative" && "$relative" != /* && "$relative" != *".."* && -f "$MACARCHY_THEME_DIR/$relative" ]]
}

macarchy_theme_selected_background() {
    local selected=""
    local jq_bin=""

    jq_bin="$(macarchy_command jq || true)"
    if [[ -n "$jq_bin" && -r "$MACARCHY_BACKGROUND_STATE" ]]; then
        selected="$("$jq_bin" -r --arg theme "$MACARCHY_THEME_NAME" '.[$theme] // empty' "$MACARCHY_BACKGROUND_STATE" 2>/dev/null || true)"
    fi
    macarchy_theme_background_valid "$selected" && { printf '%s\n' "$selected"; return 0; }
    macarchy_theme_background_valid "$THEME_WALLPAPER" && printf '%s\n' "$THEME_WALLPAPER"
}

macarchy_theme_save_background() {
    local relative="$1"
    local jq_bin temporary

    macarchy_theme_background_valid "$relative" || {
        macarchy_error "'$relative' is not a background in theme '$MACARCHY_THEME_NAME'"
        return 1
    }
    jq_bin="$(macarchy_command jq || true)"
    [[ -n "$jq_bin" ]] || { macarchy_error "jq is required to save a background choice"; return 1; }

    mkdir -p "$MACARCHY_THEMES_DIR"
    temporary="$(mktemp "$MACARCHY_THEMES_DIR/.backgrounds.XXXXXX")"
    if [[ -r "$MACARCHY_BACKGROUND_STATE" ]]; then
        "$jq_bin" --arg theme "$MACARCHY_THEME_NAME" --arg background "$relative" \
            '.[$theme] = $background' "$MACARCHY_BACKGROUND_STATE" > "$temporary"
    else
        "$jq_bin" -n --arg theme "$MACARCHY_THEME_NAME" --arg background "$relative" \
            '{($theme): $background}' > "$temporary"
    fi
    chmod 600 "$temporary"
    mv "$temporary" "$MACARCHY_BACKGROUND_STATE"
}
