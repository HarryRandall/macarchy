#!/usr/bin/env bash

# When an app is activated with only minimised windows, restore one on the
# currently focused Space instead of letting macOS revive it elsewhere.

YABAI_BIN="$(command -v "${YABAI_BIN:-yabai}" 2>/dev/null || true)"
JQ_BIN="$(command -v "${JQ_BIN:-jq}" 2>/dev/null || true)"
[ -n "$YABAI_BIN" ] && [ -n "$JQ_BIN" ] || exit 0

CONFIG_ROOT="${YABAI_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/yabai}"
REFRESH_SCRIPT="$CONFIG_ROOT/trigger_sketchybar_space_labels_refresh.sh"

pid="${YABAI_PROCESS_ID:-}"
case "$pid" in
  ''|*[!0-9]*) exit 0 ;;
esac

current_space="$("$YABAI_BIN" -m query --spaces --space 2>/dev/null | "$JQ_BIN" -r '.index // empty')"
case "$current_space" in
  ''|*[!0-9]*) exit 0 ;;
esac

windows_json="$("$YABAI_BIN" -m query --windows 2>/dev/null)"
[ -n "$windows_json" ] || exit 0

non_minimized_count="$(
  "$JQ_BIN" --argjson pid "$pid" '
    [.[] | select(.pid == $pid and ."is-minimized" == false)] | length
  ' <<<"$windows_json" 2>/dev/null
)"

if [ "${non_minimized_count:-0}" -gt 0 ]; then
  exit 0
fi

window_id="$(
  "$JQ_BIN" -r --argjson pid "$pid" '
    [.[] | select(.pid == $pid and ."is-minimized" == true)]
    | last.id // empty
  ' <<<"$windows_json" 2>/dev/null
)"

[ -n "$window_id" ] || exit 0

"$YABAI_BIN" -m window "$window_id" --space "$current_space" 2>/dev/null || true
"$YABAI_BIN" -m window --deminimize "$window_id" 2>/dev/null || true
"$YABAI_BIN" -m window --focus "$window_id" 2>/dev/null || true

# The refresh script coalesces this with the window_deminimized signal.
[ -f "$REFRESH_SCRIPT" ] && /bin/bash "$REFRESH_SCRIPT" || true
