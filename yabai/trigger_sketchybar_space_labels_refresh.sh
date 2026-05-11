#!/usr/bin/env bash

SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-$(command -v sketchybar 2>/dev/null || true)}"
[ -x "$SKETCHYBAR_BIN" ] || SKETCHYBAR_BIN="/opt/homebrew/bin/sketchybar"

"$SKETCHYBAR_BIN" --trigger yabai_space_labels_refresh >/dev/null 2>&1 || true
