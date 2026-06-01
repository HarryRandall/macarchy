#!/usr/bin/env bash

SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-$(command -v sketchybar 2>/dev/null || true)}"
[ -x "$SKETCHYBAR_BIN" ] || SKETCHYBAR_BIN="/opt/homebrew/bin/sketchybar"

CONFIG_ROOT="${CONFIG_DIR:-$HOME/.config/sketchybar}"
if [ -f "$CONFIG_ROOT/colors.sh" ]; then
  # shellcheck source=/dev/null
  source "$CONFIG_ROOT/colors.sh"
fi

YABAI_BIN="${YABAI_BIN:-$(command -v yabai 2>/dev/null || true)}"
[ -x "$YABAI_BIN" ] || YABAI_BIN="/opt/homebrew/bin/yabai"

ACCENT_COLOR="${ACCENT_COLOR:-0xffe1e1e1}"
TEXT_COLOR="${TEXT_COLOR:-0xffe1e1e1}"
ACCENT_RGB="${ACCENT_COLOR#0x}"
ACCENT_RGB="${ACCENT_RGB#\#}"
if [ "${#ACCENT_RGB}" -eq 8 ]; then
  ACCENT_RGB="${ACCENT_RGB#??}"
fi
ACTIVE_BACKGROUND_COLOR="0x1a${ACCENT_RGB}"

current_space="${1:-}"
if [ -z "$current_space" ]; then
  current_space="$("$YABAI_BIN" -m query --spaces --space 2>/dev/null | jq -r '.index // empty')"
fi

if [ -n "$current_space" ]; then
  args=()

  for sid in 1 2 3 4 5 6 7 8 9 10
  do
    if [ "$sid" = "$current_space" ]; then
      args+=(--set "space.$sid" background.drawing=on
                              background.color="$ACTIVE_BACKGROUND_COLOR"
                              background.border_width=1
                              background.border_color="$ACCENT_COLOR"
                              label.color="$ACCENT_COLOR"
                              icon.color="$ACCENT_COLOR")
    else
      args+=(--set "space.$sid" background.drawing=off
                              background.color=0x00000000
                              background.border_width=0
                              background.border_color=0x00000000
                              label.color="$TEXT_COLOR"
                              icon.color="$TEXT_COLOR")
    fi
  done

  "$SKETCHYBAR_BIN" "${args[@]}" >/dev/null 2>&1 || true
fi
