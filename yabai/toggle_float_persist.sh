#!/usr/bin/env bash

set -euo pipefail

YABAI_BIN="$(command -v "${YABAI_BIN:-yabai}" 2>/dev/null || true)"
JQ_BIN="$(command -v "${JQ_BIN:-jq}" 2>/dev/null || true)"
[ -n "$YABAI_BIN" ] && [ -n "$JQ_BIN" ] || exit 0

CONFIG_ROOT="${YABAI_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/yabai}"
STATE_FILE="$CONFIG_ROOT/float_state.json"
SYNC_SCRIPT="$CONFIG_ROOT/sync_float_rules.sh"

mkdir -p "$(dirname "$STATE_FILE")"
[[ -f "$STATE_FILE" ]] || printf '[]\n' > "$STATE_FILE"
if ! "$JQ_BIN" -e 'type == "array" and all(.[]; type == "string")' "$STATE_FILE" >/dev/null 2>&1; then
  printf '[]\n' > "$STATE_FILE"
fi

window_json="$("$YABAI_BIN" -m query --windows --window)"
app_name="$("$JQ_BIN" -r '.app // empty' <<<"$window_json")"
is_floating="$("$JQ_BIN" -r '."is-floating" // false' <<<"$window_json")"

if [[ -z "$app_name" ]]; then
  exit 0
fi

"$YABAI_BIN" -m window --toggle float

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

if [[ "$is_floating" == "true" ]]; then
  "$JQ_BIN" --arg app "$app_name" 'map(select(. != $app))' "$STATE_FILE" > "$tmp_file"
else
  "$JQ_BIN" --arg app "$app_name" '
    (if type == "array" then . else [] end) + [$app] | unique
  ' "$STATE_FILE" > "$tmp_file"
fi

mv "$tmp_file" "$STATE_FILE"
trap - EXIT

if [[ -x "$SYNC_SCRIPT" ]]; then
  "$SYNC_SCRIPT"
fi
