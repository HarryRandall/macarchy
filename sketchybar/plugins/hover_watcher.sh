#!/usr/bin/env bash

CONFIG_ROOT="${CONFIG_DIR:-$HOME/.config/sketchybar}"
THEME_FILE="$CONFIG_ROOT/theme.sh"
STATE_DIR="$CONFIG_ROOT/.state"
STATE_FILE="$STATE_DIR/bar_hidden"

if [ -f "$THEME_FILE" ]; then
  source "$THEME_FILE"
fi

hidden_y_offset="${BAR_HIDDEN_Y_OFFSET:--40}"
top_zone="${BAR_TRIGGER_ZONE:-${BAR_HEIGHT:-34}}"

distance_from_top="$(swift -e '
import AppKit

let point = NSEvent.mouseLocation
let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }) ?? NSScreen.main
let distance = Int((screen?.frame.maxY ?? point.y) - point.y)
print(distance)
' 2>/dev/null)"

[ -n "$distance_from_top" ] || exit 0

should_hide=0
if [ "$distance_from_top" -le "$top_zone" ]; then
  should_hide=1
fi

mkdir -p "$STATE_DIR"

current_hidden=0
if [ -f "$STATE_FILE" ]; then
  current_hidden="$(cat "$STATE_FILE")"
fi

if [ "$current_hidden" = "$should_hide" ]; then
  exit 0
fi

printf '%s\n' "$should_hide" >"$STATE_FILE"

if [ "$should_hide" = "1" ]; then
  sketchybar --animate tanh 2 --bar y_offset="$hidden_y_offset"
else
  sketchybar --animate tanh 2 --bar y_offset=0
fi
