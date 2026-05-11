#!/usr/bin/env bash

THEME_FILE="${CONFIG_DIR:-$HOME/.config/sketchybar}/theme.sh"
if [ -f "$THEME_FILE" ]; then
  # shellcheck source=/dev/null
  source "$THEME_FILE"
fi

DATE_FORMAT="${CLOCK_DATE_FORMAT:-+%a %d %b %I:%M %p}"
sketchybar --set "$NAME" label="$(date "$DATE_FORMAT")"
