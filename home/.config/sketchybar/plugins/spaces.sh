#!/bin/bash

THEME_FILE="${CONFIG_DIR:-$HOME/.config/sketchybar}/theme.sh"
if [ -f "$THEME_FILE" ]; then
  # shellcheck source=/dev/null
  source "$THEME_FILE"
fi

if [ "$SELECTED" = "true" ]; then
  sketchybar --set "$NAME" \
    icon.highlight=on \
    label.highlight=on \
    icon.color="${ACCENT_COLOR:-0xff7e9cd8}" \
    label.color="${ACCENT_COLOR:-0xff7e9cd8}" \
    background.drawing=off
else
  sketchybar --set "$NAME" \
    icon.highlight=off \
    label.highlight=off \
    icon.color="${TEXT_COLOR:-0xff000000}" \
    label.color="${TEXT_COLOR:-0xff000000}" \
    background.drawing=off
fi
