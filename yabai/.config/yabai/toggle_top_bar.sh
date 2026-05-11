#!/usr/bin/env bash

set -u

STATE_FILE="${HOME}/.config/yabai/.top_bar_hidden"

mkdir -p "$(dirname "$STATE_FILE")"

is_hidden=0
if [ -f "$STATE_FILE" ]; then
  is_hidden=1
fi

if [ "$is_hidden" -eq 1 ]; then
  rm -f "$STATE_FILE"
  sketchybar --bar hidden=off >/dev/null 2>&1 || true
else
  : >"$STATE_FILE"
  sketchybar --bar hidden=on >/dev/null 2>&1 || true
fi
