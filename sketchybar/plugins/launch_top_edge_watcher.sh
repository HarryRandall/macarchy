#!/usr/bin/env bash

set -euo pipefail

CONFIG_ROOT="${CONFIG_DIR:-$HOME/.config/sketchybar}"
THEME_FILE="$CONFIG_ROOT/theme.sh"
STATE_DIR="$CONFIG_ROOT/.state"
SOURCE="$CONFIG_ROOT/plugins/top_edge_watcher.swift"
BINARY="$CONFIG_ROOT/plugins/top_edge_watcher"
SKETCHYBAR_BIN="$(command -v sketchybar)"
SWIFTC_BIN="$(command -v swiftc)"

mkdir -p "$STATE_DIR"

if [ -f "$THEME_FILE" ]; then
  source "$THEME_FILE"
fi

if [ ! -x "$SWIFTC_BIN" ]; then
  exit 1
fi

if [ ! -x "$BINARY" ] || [ "$SOURCE" -nt "$BINARY" ]; then
  "$SWIFTC_BIN" -O -o "$BINARY" "$SOURCE"
fi

exec "$BINARY" \
  --sketchybar "$SKETCHYBAR_BIN" \
  --top-zone "${BAR_TRIGGER_ZONE:-${BAR_HEIGHT:-34}}" \
  --hidden-offset "${BAR_HIDDEN_Y_OFFSET:--40}" \
  --poll-interval "${BAR_VISIBILITY_POLL_INTERVAL:-0.05}"
