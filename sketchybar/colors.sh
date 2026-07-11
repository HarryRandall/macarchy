#!/bin/bash

THEME_FILE="${CONFIG_DIR:-$HOME/.config/sketchybar}/theme.sh"

if [ -f "$THEME_FILE" ]; then
  # shellcheck source=/dev/null
  source "$THEME_FILE"
fi

export WARNING_COLOR=0xffFFD60A
export DANGER_COLOR=0xffff453a

# These defaults keep the bar neutral until a Macarchy theme is applied.
export BAR_COLOR="${BAR_COLOR:-0x00000000}"
export ACCENT_COLOR="${ACCENT_COLOR:-0xff2cf9ed}"
export TEXT_COLOR="${TEXT_COLOR:-0xffffffff}"
export WHITE="$TEXT_COLOR"
