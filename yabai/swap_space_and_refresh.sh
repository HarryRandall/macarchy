#!/usr/bin/env bash

set -euo pipefail

target_space="${1:-}"

case "$target_space" in
  ''|*[!0-9]*|0)
    exit 1
    ;;
esac

YABAI_BIN="$(command -v "${YABAI_BIN:-yabai}" 2>/dev/null || true)"
JQ_BIN="$(command -v "${JQ_BIN:-jq}" 2>/dev/null || true)"
[ -n "$YABAI_BIN" ] && [ -n "$JQ_BIN" ] || exit 0

CONFIG_ROOT="${YABAI_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/yabai}"
REFRESH_SCRIPT="$CONFIG_ROOT/trigger_sketchybar_space_labels_refresh.sh"

current_space="$("$YABAI_BIN" -m query --spaces --space | "$JQ_BIN" -r '.index // empty')"
[ -n "$current_space" ] || exit 1

if [ "$current_space" != "$target_space" ]; then
  "$YABAI_BIN" -m space --swap "$target_space"
fi

[ -f "$REFRESH_SCRIPT" ] && /bin/bash "$REFRESH_SCRIPT" || true
