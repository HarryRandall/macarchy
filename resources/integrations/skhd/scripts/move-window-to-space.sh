#!/bin/bash
# Bundled with Macarchy for the default shortcuts. Moves the focused window to
# a Space and follows it there: move-window-to-space.sh <number>
set -uo pipefail
target="${1:-}"
case "$target" in
  '' | *[!0-9]* | 0) exit 64 ;;
esac

# The window is read before the move so it can be focused again on the far
# side. With no focused window, such as on an empty Space, the Space still
# changes. A Space that does not exist yet makes both steps a silent no-op.
window="$(yabai -m query --windows --window 2>/dev/null | jq -r '.id // empty' 2>/dev/null)"
if [ -n "$window" ]; then
  yabai -m window "$window" --space "$target" 2>/dev/null || window=""
fi

# The command tells the bar which Space is next before yabai switches.
macarchy space "$target" 2>/dev/null || exit 0
if [ -n "$window" ]; then
  yabai -m window --focus "$window" 2>/dev/null || true
fi
