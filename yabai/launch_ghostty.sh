#!/usr/bin/env bash

set -euo pipefail

open -na Ghostty
sleep 0.35

id="$(yabai -m query --windows 2>/dev/null | jq -r 'map(select(.app == "Ghostty")) | sort_by(.id) | last | .id // empty')"
[[ -n "$id" ]] || exit 0

is_floating="$(yabai -m query --windows --window "$id" 2>/dev/null | jq -r '."is-floating" // false')"
if [[ "$is_floating" == "true" ]]; then
  yabai -m window "$id" --toggle float
fi

yabai -m window --focus "$id" 2>/dev/null || true
