#!/usr/bin/env bash

macarchy_ghostty_colour() {
    local file="$1"
    local key="$2"
    local fallback="$3"
    local value

    value="$(awk -F= -v key="$key" '
        {
            name=$1
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
            if (name == key) {
                value=substr($0, index($0, "=") + 1)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
                print value
                exit
            }
        }
    ' "$file" 2>/dev/null)"

    [[ "$value" =~ ^#[0-9A-Fa-f]{6}$ ]] && printf '%s\n' "$value" || printf '%s\n' "$fallback"
}

macarchy_ghostty_palette() {
    local file="$1"
    local index="$2"
    local fallback="$3"
    local value

    value="$(awk -F= -v wanted="$index" '
        /^[[:space:]]*palette[[:space:]]*=/ {
            palette_index=$2
            colour=$3
            gsub(/[[:space:]]/, "", palette_index)
            gsub(/[[:space:]]/, "", colour)
            if (palette_index == wanted && colour ~ /^#[0-9A-Fa-f]{6}$/) {
                print colour
                exit
            }
        }
    ' "$file" 2>/dev/null)"

    [[ "$value" =~ ^#[0-9A-Fa-f]{6}$ ]] && printf '%s\n' "$value" || printf '%s\n' "$fallback"
}

macarchy_ghostty_palette_index() {
    local file="$1"
    local wanted="${2#\#}"

    awk -F= -v wanted="$wanted" '
        BEGIN { wanted=tolower(wanted) }
        /^[[:space:]]*palette[[:space:]]*=/ {
            palette_index=$2
            colour=$3
            gsub(/[[:space:]]/, "", palette_index)
            gsub(/[[:space:]]/, "", colour)
            sub(/^#/, "", colour)
            if (tolower(colour) == wanted) {
                print palette_index
                exit
            }
        }
    ' "$file" 2>/dev/null
}

# Ghostty theme files are restricted to colours and a small set of visual
# settings used by the original packs. Commands, fonts and input behaviour are
# still rejected.
macarchy_ghostty_theme_valid() {
    local file="$1"
    awk -F= '
        /^[[:space:]]*($|#)/ { next }
        {
            key=$1
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
            value=substr($0, index($0, "=") + 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            if (key == "palette") {
                if (value !~ /^[0-9]+=#[0-9A-Fa-f]{6}$/) exit 1
            } else if (key ~ /^(background|foreground|cursor-color|cursor-text|selection-background|selection-foreground)$/) {
                if (value !~ /^#[0-9A-Fa-f]{6}$/) exit 1
            } else if (key == "background-opacity") {
                if (value !~ /^(0([.][0-9]+)?|1([.]0+)?)$/) exit 1
            } else if (key ~ /^(window-padding-x|window-padding-y)$/) {
                if (value !~ /^[0-9]+([.][0-9]+)?(,[[:space:]]*[0-9]+([.][0-9]+)?)?$/) exit 1
            } else if (key == "window-padding-balance") {
                if (value !~ /^(true|false)$/) exit 1
            } else {
                exit 1
            }
        }
    ' "$file"
}
