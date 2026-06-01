#!/usr/bin/env bash

# When an app is activated with only minimized windows, restore one on the
# currently focused Space instead of letting macOS revive it elsewhere.

YABAI_BIN="${YABAI_BIN:-$(command -v yabai 2>/dev/null || true)}"
[ -x "$YABAI_BIN" ] || YABAI_BIN="/opt/homebrew/bin/yabai"

pid="${YABAI_PROCESS_ID:-}"
[ -n "$pid" ] || exit 0

current_space="$("$YABAI_BIN" -m query --spaces --space 2>/dev/null | jq -r '.index // empty')"
[ -n "$current_space" ] || exit 0

windows_json="$("$YABAI_BIN" -m query --windows 2>/dev/null)"
[ -n "$windows_json" ] || exit 0

non_minimized_count="$(
  jq --argjson pid "$pid" '
    [.[] | select(.pid == $pid and ."is-minimized" == false)] | length
  ' <<<"$windows_json" 2>/dev/null
)"

if [ "${non_minimized_count:-0}" -gt 0 ]; then
  exit 0
fi

window_id="$(
  jq -r --argjson pid "$pid" '
    [.[] | select(.pid == $pid and ."is-minimized" == true)]
    | last.id // empty
  ' <<<"$windows_json" 2>/dev/null
)"

[ -n "$window_id" ] || exit 0

"$YABAI_BIN" -m window "$window_id" --space "$current_space" 2>/dev/null || true
"$YABAI_BIN" -m window "$window_id" --deminimize 2>/dev/null || true
"$YABAI_BIN" -m window "$window_id" --focus 2>/dev/null || true
