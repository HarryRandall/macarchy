#!/usr/bin/env bash

set -euo pipefail

target_space="${1:-}"

case "$target_space" in
  ''|*[!0-9]*)
    exit 1
    ;;
esac

YABAI_BIN="${YABAI_BIN:-$(command -v yabai 2>/dev/null || true)}"
[ -x "$YABAI_BIN" ] || YABAI_BIN="/opt/homebrew/bin/yabai"

SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-$(command -v sketchybar 2>/dev/null || true)}"
[ -x "$SKETCHYBAR_BIN" ] || SKETCHYBAR_BIN="/opt/homebrew/bin/sketchybar"

refresh_bar() {
  /bin/bash "$HOME/.config/yabai/trigger_sketchybar_space_labels_refresh.sh" "$target_space"
  [ -x "$SKETCHYBAR_BIN" ] && "$SKETCHYBAR_BIN" --trigger yabai_space_labels_refresh >/dev/null 2>&1 || true
}

current_space="$("$YABAI_BIN" -m query --spaces --space | jq -r '.index')"

if [ "$current_space" != "$target_space" ]; then
  "$YABAI_BIN" -m space --swap "$target_space"
  refresh_bar
  sleep 0.20
  "$YABAI_BIN" -m space --focus "$target_space"
fi

for delay in 0.05 0.20 0.50
do
  sleep "$delay"
  refresh_bar
done
