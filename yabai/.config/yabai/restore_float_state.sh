#!/usr/bin/env bash

set -euo pipefail

STATE_FILE="${HOME}/.config/yabai/float_state.json"

[[ -f "$STATE_FILE" ]] || exit 0
if ! jq empty "$STATE_FILE" >/dev/null 2>&1; then
  exit 0
fi

window_id="${YABAI_WINDOW_ID:-}"
[[ -n "$window_id" ]] || exit 0

window_json="$(yabai -m query --windows --window "$window_id")"
app_name="$(jq -r '.app // empty' <<<"$window_json")"
is_floating="$(jq -r '."is-floating" // false' <<<"$window_json")"

if [[ -z "$app_name" || "$is_floating" == "true" ]]; then
  exit 0
fi

should_float="$(jq -r --arg app "$app_name" 'index($app) != null' "$STATE_FILE")"

if [[ "$should_float" == "true" ]]; then
  yabai -m window "$window_id" --toggle float
fi
