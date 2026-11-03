#!/bin/bash
# Bundled with Macarchy for the default shortcuts. Opens a new Ghostty window,
# tiled and focused, or a Terminal window when Ghostty is not installed.
set -uo pipefail

if ! command -v yabai >/dev/null || ! command -v jq >/dev/null; then
  open -na Ghostty 2>/dev/null || open -na Terminal
  exit
fi

ghostty_windows='map(select(.app == "Ghostty")) | map(.id)'
before="$(yabai -m query --windows 2>/dev/null | jq -c "$ghostty_windows" 2>/dev/null)"
open -na Ghostty 2>/dev/null || exec open -na Terminal

# The new window is the one missing from the earlier set. Taking the highest
# id after a fixed wait instead raced with Ghostty opening it.
window=""
for _ in $(seq 1 30); do
  sleep 0.1
  window="$(yabai -m query --windows 2>/dev/null \
    | jq -r --argjson before "${before:-[]}" "$ghostty_windows - \$before | last // empty" \
      2>/dev/null)"
  [ -n "$window" ] && break
done
[ -n "$window" ] || exit 0

# A new Ghostty window can open floating; this shortcut always tiles it.
floating="$(yabai -m query --windows --window "$window" 2>/dev/null | jq -r '."is-floating" // false')"
if [ "$floating" = true ]; then
  yabai -m window "$window" --toggle float
fi
yabai -m window --focus "$window" 2>/dev/null || true
