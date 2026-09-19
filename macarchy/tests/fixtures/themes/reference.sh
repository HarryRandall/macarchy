#!/bin/bash
set -euo pipefail
THEME_DIR="$1"
THEME="$(basename "$1")"
THEMES_DIR="$2"
BTOP_THEME_DIR="$2"
BTOP_THEME_NAME=active-theme
source "$THEME_DIR/theme.env"
ghostty_color() {
    local key="$1"
    local fallback="$2"
    local value=""

    if [ -f "$THEME_DIR/ghostty.conf" ]; then
        value="$(grep -E "^${key}[[:space:]]*=[[:space:]]*#[0-9A-Fa-f]{6}$" "$THEME_DIR/ghostty.conf" | sed -E "s/^${key}[[:space:]]*=[[:space:]]*//" | head -n 1 || true)"
    fi

    if [ -n "$value" ]; then
        printf '%s\n' "$value"
    else
        printf '%s\n' "$fallback"
    fi
}
ghostty_palette() {
    local index="$1"
    local fallback="$2"
    local value=""

    if [ -f "$THEME_DIR/ghostty.conf" ]; then
        value="$(grep -E "^palette[[:space:]]*=[[:space:]]*$index=#[0-9A-Fa-f]{6}$" "$THEME_DIR/ghostty.conf" | sed -E 's/^palette[[:space:]]*=[[:space:]]*[0-9]+=//' | head -n 1 || true)"
    fi

    if [ -n "$value" ]; then
        printf '%s\n' "$value"
    else
        printf '%s\n' "$fallback"
    fi
}
write_btop_theme() {
    mkdir -p "$BTOP_THEME_DIR"

    local bg fg selection accent muted green yellow red cyan purple orange
    bg="$(ghostty_color "background" "#000000")"
    fg="$(ghostty_color "foreground" "#ffffff")"
    selection="$(ghostty_color "selection-background" "$bg")"
    accent="$(ghostty_palette 4 "$fg")"
    muted="$(ghostty_palette 8 "$fg")"
    green="$(ghostty_palette 2 "$accent")"
    yellow="$(ghostty_palette 3 "$accent")"
    red="$(ghostty_palette 1 "$accent")"
    cyan="$(ghostty_palette 6 "$accent")"
    purple="$(ghostty_palette 5 "$accent")"
    orange="$(ghostty_palette 11 "$yellow")"

    cat > "$BTOP_THEME_DIR/$BTOP_THEME_NAME.theme" <<EOF
# Auto-generated from theme-switch for $THEME
theme[main_bg]=""
theme[main_fg]="$fg"
theme[title]="$fg"
theme[hi_fg]="$accent"
theme[selected_bg]="$selection"
theme[selected_fg]="$fg"
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
write_shell_env() {
    # Accent priority: SYSTEM_ACCENT_COLOR -> FIREFOX_ACCENT
    # -> BORDER_ACTIVE -> palette[4]. We walk this list and pick the first
    # candidate whose hex actually matches a palette slot — that's the index
    # we need so ghostty palette-reload recolours scrollback live.
    _palette_idx_for_hex() {
        local h="${1#\#}"
        [[ "$h" =~ ^[0-9A-Fa-f]{6}$ ]] || return 0
        [ -f "$THEME_DIR/ghostty.conf" ] || return 0
        awk -v want="$(printf '%s' "$h" | tr 'A-F' 'a-f')" '
            tolower($0) ~ "^palette[[:space:]]*=[[:space:]]*[0-9]+=#" want "$" {
                sub(/^palette[[:space:]]*=[[:space:]]*/, "", $0)
                split($0, p, "=")
                print p[1]
                exit
            }' "$THEME_DIR/ghostty.conf"
    }
    local border_hex=""
    if [[ "${BORDER_ACTIVE:-}" =~ ^0x[fF]{2}([0-9A-Fa-f]{6})$ ]]; then
        border_hex="${BASH_REMATCH[1]}"
    fi
    local palette4_hex=""
    if [ -f "$THEME_DIR/ghostty.conf" ]; then
        palette4_hex=$(awk '/^palette[[:space:]]*=[[:space:]]*4=#[0-9A-Fa-f]{6}$/ {
            sub(/.*=#/, ""); print; exit
        }' "$THEME_DIR/ghostty.conf")
    fi
    local accent_idx="" accent_hex="" candidate
    for candidate in "${SYSTEM_ACCENT_COLOR:-}" "${FIREFOX_ACCENT:-}" "$border_hex" "$palette4_hex"; do
        candidate="${candidate#\#}"
        [[ "$candidate" =~ ^[0-9A-Fa-f]{6}$ ]] || continue
        accent_idx=$(_palette_idx_for_hex "$candidate")
        if [ -n "$accent_idx" ]; then
            accent_hex="$candidate"
            break
        fi
    done
    # Last-resort fallback: palette slot 4.
    [ -z "$accent_idx" ] && { accent_idx=4; accent_hex="${palette4_hex:-}"; }

    local fg_idx=15
    [ "${DARK_MODE:-true}" = "false" ] && fg_idx=0
    local mut_idx=8

    local acc="38;5;${accent_idx}"
    local mut="38;5;${mut_idx}"
    # Override only what's theme-specific: directories/executables get the
    # accent, links stay muted grey. Everything else (perms, user, date,
    # size, etc.) uses eza's stock palette-based defaults — which already
    # repaint on theme reload because they're indexed colours.
    local eza="di=${acc}:ex=1;${acc}:ln=${mut}:xx=${mut}"

    local fg_hex="ffffff"
    [ "${DARK_MODE:-true}" = "false" ] && fg_hex="000000"

    local env_file="$THEMES_DIR/.shell-env"
    {
        echo "# Auto-generated by theme-switch. Do not edit."
        echo "export EZA_COLORS='${eza}'"
        echo "export MACARCHY_ACCENT_IDX='${accent_idx}'"
        echo "export MACARCHY_FG_IDX='${fg_idx}'"
        echo "export MACARCHY_ACCENT='#${accent_hex:-${fg_hex}}'"
        echo "export MACARCHY_FG='#${fg_hex}'"
        echo "export MACARCHY_DARK_MODE='${DARK_MODE:-true}'"
    } > "$env_file"
    echo "  Shell env: accent_idx=${accent_idx} fg_idx=${fg_idx} -> $env_file"
}
map_nvim_colorscheme() {
    local theme_name="${1:-}"
    case "$theme_name" in
        flexoki-light)
            printf 'flexoki-light\n'
            ;;
        kanagawa)
            printf 'kanagawa-wave\n'
            ;;
        nord)
            printf 'nord\n'
            ;;
        aetheria|futurism|aura)
            printf 'tokyonight-night\n'
            ;;
        akane|sakura)
            printf 'rose-pine-moon\n'
            ;;
        awakening|pulsar|firesky|nes|batou|blackgold)
            printf 'gruvbox\n'
            ;;
        midnight)
            printf 'tokyonight-night\n'
            ;;
        blackturq)
            printf 'nord\n'
            ;;
        carbonfox)
            printf 'tokyonight-night\n'
            ;;
        killer-klownz)
            printf 'aether\n'
            ;;
        florida-man)
            printf 'catppuccin\n'
            ;;
        catppuccin)
            printf 'catppuccin\n'
            ;;
        retro-82)
            printf 'gruvbox\n'
            ;;
        lumon)
            printf 'rose-pine-dawn\n'
            ;;
        matte-black)
            printf 'gruvbox\n'
            ;;
        vantablack|hackerman)
            printf 'tokyonight-night\n'
            ;;
        osaka-jade)
            printf 'rose-pine-main\n'
            ;;
        *)
            printf '%s\n' "${NVIM_COLORSCHEME:-tokyonight}"
            ;;
    esac
}
write_btop_theme
write_shell_env >/dev/null
map_nvim_colorscheme "$THEME" > "$2/nvim"
