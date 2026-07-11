#!/usr/bin/env bash

set -u

SKETCHYBAR_BIN="$(command -v "${SKETCHYBAR_BIN:-sketchybar}" 2>/dev/null || true)"
JQ_BIN="$(command -v "${JQ_BIN:-jq}" 2>/dev/null || true)"
[ -n "$SKETCHYBAR_BIN" ] && [ -n "$JQ_BIN" ] || exit 0

hidden="$("$SKETCHYBAR_BIN" --query bar 2>/dev/null | "$JQ_BIN" -r '.hidden // "off"' 2>/dev/null || printf 'off')"

if [ "$hidden" = "on" ]; then
  "$SKETCHYBAR_BIN" --bar hidden=off >/dev/null 2>&1 || true
else
  "$SKETCHYBAR_BIN" --bar hidden=on >/dev/null 2>&1 || true
fi
