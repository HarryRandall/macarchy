#!/bin/bash
set -uo pipefail

# Native switching verified with the macOS 27 fork on 2026-09-19.
#
# yabai already no-ops on a Space that does not exist yet, so bindings for Spaces
# you have not created still do nothing and start working once you add them — no
# validating query needed. Dropping the pre-flight queries takes the plain switch
# from five processes to one, which is time straight off the front of the
# perceived switch latency.
YABAI=/opt/homebrew/bin/yabai
JQ=/opt/homebrew/bin/jq
# Macarchy tells the bar which Space is next before asking yabai to switch, so
# the bar shows it as you arrive. The development copy for now; without it,
# yabai switches on its own as before.
MACARCHY="$HOME/Applications/Macarchy Dev.app/Contents/MacOS/macarchy"
focus() {
  if [[ -x "$MACARCHY" ]]; then "$MACARCHY" space "$1"; else "$YABAI" -m space --focus "$1"; fi
}
target="${1:-}"
case "$target" in
  ''|*[!0-9]*|0) exit 64 ;;
esac

if [[ "${2:-}" != move ]]; then
  focus "$target" 2>/dev/null
  exit
fi

# Move-and-follow: the window id has to be read before the move so focus can be
# restored to it on the far side. No focused window (empty Space, unmanaged
# window) must still switch.
window_id="$("$YABAI" -m query --windows --window 2>/dev/null | "$JQ" -r '.id // empty' 2>/dev/null || true)"
if [[ -n "$window_id" ]]; then
  "$YABAI" -m window "$window_id" --space "$target" 2>/dev/null || window_id=""
fi

focus "$target" 2>/dev/null || exit 0

if [[ -n "$window_id" ]]; then
  "$YABAI" -m window --focus "$window_id" 2>/dev/null || true
fi
