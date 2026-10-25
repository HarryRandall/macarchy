#!/usr/bin/env bash

set -euo pipefail

# Identify the newly opened window by diffing the Ghostty window-id set,
# rather than assuming the highest id after a fixed sleep (which raced).
# jq does the set difference: a `case` pattern inside $( ) breaks on the
# bash 3.2 that ships with macOS.

before="$(yabai -m query --windows 2>/dev/null \
  | jq -c 'map(select(.app == "Ghostty")) | map(.id)' 2>/dev/null || echo '[]')"

open -na Ghostty

id=""
for _ in $(seq 1 30); do
  sleep 0.1
  id="$(yabai -m query --windows 2>/dev/null \
    | jq -r --argjson before "$before" \
        'map(select(.app == "Ghostty")) | map(.id) - $before | last // empty' \
        2>/dev/null || true)"
  [ -n "$id" ] && break
done
[ -n "$id" ] || exit 0

is_floating="$(yabai -m query --windows --window "$id" 2>/dev/null | jq -r '."is-floating" // false')"
if [[ "$is_floating" == "true" ]]; then
  yabai -m window "$id" --toggle float
fi

yabai -m window --focus "$id" 2>/dev/null || true
