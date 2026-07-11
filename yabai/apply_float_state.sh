#!/usr/bin/env bash
# Called by yabai signals (window_created, window_deminimized).
# YABAI_WINDOW_ID is injected by yabai into the signal environment.

YABAI_BIN="$(command -v "${YABAI_BIN:-yabai}" 2>/dev/null || true)"
JQ_BIN="$(command -v "${JQ_BIN:-jq}" 2>/dev/null || true)"
[ -n "$YABAI_BIN" ] && [ -n "$JQ_BIN" ] || exit 0

window_id="${YABAI_WINDOW_ID:-}"
case "$window_id" in
  ''|*[!0-9]*) exit 0 ;;
esac

CONFIG_ROOT="${YABAI_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/yabai}"
STATE_FILE="$CONFIG_ROOT/float_state.json"
[[ -f "$STATE_FILE" ]] || exit 0

window_json="$("$YABAI_BIN" -m query --windows --window "$window_id" 2>/dev/null)"
app="$("$JQ_BIN" -r '.app // empty' <<<"$window_json")"
[[ -n "$app" ]] || exit 0

in_state="$("$JQ_BIN" --arg a "$app" 'if type == "array" then map(select(. == $a)) | length else 0 end' "$STATE_FILE" 2>/dev/null)"
[[ "$in_state" -gt 0 ]] || exit 0

is_floating="$("$JQ_BIN" -r '."is-floating" // false' <<<"$window_json")"
if [[ "$is_floating" != "true" ]]; then
  # yabai 7 exposes floating as a toggle, so guard it with the queried state.
  "$YABAI_BIN" -m window "$window_id" --toggle float 2>/dev/null || true
fi
