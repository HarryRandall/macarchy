#!/bin/bash

CONFIG_ROOT="${CONFIG_DIR:-$HOME/.config/sketchybar}"

# shellcheck source=/dev/null
source "$CONFIG_ROOT/plugins/icon_map.sh"

front_app="$INFO"

if [ -z "$front_app" ]; then
  front_app="$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null || true)"
fi

if [ -n "$front_app" ]; then
  __icon_map "$front_app"
  sketchybar --set "$NAME" label="$front_app" icon="${icon_result:-:default:}"
fi
