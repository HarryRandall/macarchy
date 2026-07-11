#!/usr/bin/env bash

SKETCHYBAR_BIN="$(command -v "${SKETCHYBAR_BIN:-sketchybar}" 2>/dev/null || true)"
[ -n "$SKETCHYBAR_BIN" ] || exit 0

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/macarchy"
REQUEST_FILE="$STATE_DIR/space-label-refresh"
mkdir -p "$STATE_DIR"

# Several yabai signals can describe one transition. Only the newest request
# should redraw labels after the window and Space queries have settled.
token="$$.${RANDOM:-0}"
tmp_file="$REQUEST_FILE.$token"
printf '%s\n' "$token" > "$tmp_file"
mv "$tmp_file" "$REQUEST_FILE"
sleep "${SPACE_REFRESH_DELAY:-0.08}"
[ "$(cat "$REQUEST_FILE" 2>/dev/null)" = "$token" ] || exit 0

"$SKETCHYBAR_BIN" --trigger yabai_space_labels_refresh >/dev/null 2>&1 || true
