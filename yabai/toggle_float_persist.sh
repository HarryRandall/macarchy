#!/usr/bin/env bash

set -euo pipefail

STATE_FILE="${HOME}/.config/yabai/float_state.json"

mkdir -p "$(dirname "$STATE_FILE")"
[[ -f "$STATE_FILE" ]] || printf '[]\n' > "$STATE_FILE"
if ! jq empty "$STATE_FILE" >/dev/null 2>&1; then
  printf '[]\n' > "$STATE_FILE"
fi

window_json="$(yabai -m query --windows --window)"
app_name="$(jq -r '.app // empty' <<<"$window_json")"
is_floating="$(jq -r '."is-floating" // false' <<<"$window_json")"

if [[ -z "$app_name" ]]; then
  exit 0
fi

yabai -m window --toggle float

tmp_file="$(mktemp)"

if [[ "$is_floating" == "true" ]]; then
  jq --arg app "$app_name" 'map(select(. != $app))' "$STATE_FILE" > "$tmp_file"
else
  jq --arg app "$app_name" '
    (if type == "array" then . else [] end) + [$app] | unique
  ' "$STATE_FILE" > "$tmp_file"
fi

mv "$tmp_file" "$STATE_FILE"
