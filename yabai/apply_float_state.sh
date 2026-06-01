#!/usr/bin/env bash
# Called by yabai signals (window_created, window_deminimized).
# YABAI_WINDOW_ID is injected by yabai into the signal environment.

STATE_FILE="$HOME/.config/yabai/float_state.json"
[[ -f "$STATE_FILE" ]] || exit 0

window_json="$(yabai -m query --windows --window "$YABAI_WINDOW_ID" 2>/dev/null)"
app="$(jq -r '.app // empty' <<<"$window_json")"
[[ -n "$app" ]] || exit 0

in_state="$(jq --arg a "$app" 'map(select(. == $a)) | length' "$STATE_FILE" 2>/dev/null)"
[[ "$in_state" -gt 0 ]] || exit 0

is_floating="$(jq -r '."is-floating"' <<<"$window_json")"
if [[ "$is_floating" != "true" ]]; then
  yabai -m window "$YABAI_WINDOW_ID" --float 2>/dev/null || true
  yabai -m window "$YABAI_WINDOW_ID" --grid 6:6:1:1:4:4 2>/dev/null || true
fi
