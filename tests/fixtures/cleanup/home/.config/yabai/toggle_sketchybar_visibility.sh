#!/usr/bin/env bash
set -u

SKETCHYBAR_BIN="/opt/homebrew/bin/sketchybar"
JQ_BIN="/opt/homebrew/bin/jq"

hidden="$("$SKETCHYBAR_BIN" --query bar 2>/dev/null | "$JQ_BIN" -r '.hidden // "off"' 2>/dev/null || printf 'off')"

if [ "$hidden" = "on" ]; then
  "$SKETCHYBAR_BIN" --bar hidden=off
else
  "$SKETCHYBAR_BIN" --bar hidden=on
fi
