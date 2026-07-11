#!/usr/bin/env bash

set -u

CONFIG_ROOT="${YABAI_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/yabai}"
STATE_FILE="$CONFIG_ROOT/.sketchybar_hidden"
SKETCHYBAR_BIN="$(command -v "${SKETCHYBAR_BIN:-sketchybar}" 2>/dev/null || true)"
[ -n "$SKETCHYBAR_BIN" ] || exit 0

mkdir -p "$(dirname "$STATE_FILE")"

is_hidden=0
if [ -f "$STATE_FILE" ]; then
  is_hidden=1
fi

if [ "$is_hidden" -eq 1 ]; then
  rm -f "$STATE_FILE"
  "$SKETCHYBAR_BIN" --bar hidden=off >/dev/null 2>&1 || true
else
  : >"$STATE_FILE"
  "$SKETCHYBAR_BIN" --bar hidden=on >/dev/null 2>&1 || true
fi
