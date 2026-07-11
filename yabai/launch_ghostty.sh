#!/usr/bin/env bash

set -euo pipefail

YABAI_BIN="$(command -v "${YABAI_BIN:-yabai}" 2>/dev/null || true)"
JQ_BIN="$(command -v "${JQ_BIN:-jq}" 2>/dev/null || true)"
[ -n "$YABAI_BIN" ] && [ -n "$JQ_BIN" ] || exit 0

open -na Ghostty
sleep 0.35

id="$("$YABAI_BIN" -m query --windows 2>/dev/null | "$JQ_BIN" -r 'map(select(.app == "Ghostty")) | sort_by(.id) | last | .id // empty')"
[[ -n "$id" ]] || exit 0

is_floating="$("$YABAI_BIN" -m query --windows --window "$id" 2>/dev/null | "$JQ_BIN" -r '."is-floating" // false')"
if [[ "$is_floating" == "true" ]]; then
  "$YABAI_BIN" -m window "$id" --toggle float
fi

"$YABAI_BIN" -m window --focus "$id" 2>/dev/null || true
