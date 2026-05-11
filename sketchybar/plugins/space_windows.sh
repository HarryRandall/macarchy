#!/bin/bash

CONFIG_ROOT="${CONFIG_DIR:-$HOME/.config/sketchybar}"
YABAI_BIN="${YABAI_BIN:-$(command -v yabai 2>/dev/null || true)}"
[ -x "$YABAI_BIN" ] || YABAI_BIN="/opt/homebrew/bin/yabai"

# shellcheck source=/dev/null
source "$CONFIG_ROOT/plugins/icon_map.sh"

SPACE_IDS=(1 2 3 4 5 6)

map_app_icon() {
  __icon_map "$1"
  printf '%s\n' "${icon_result:-:default:}"
}

render_space() {
  local space="$1"
  local apps="$2"
  local icon_strip=" "
  local app

  if [ -n "$apps" ]; then
    while IFS= read -r app
    do
      [ -n "$app" ] || continue
      icon_strip+=" $(map_app_icon "$app")"
    done <<< "$apps"
  else
    icon_strip=" —"
  fi

  sketchybar --set "space.$space" label="$icon_strip"
}

apps_for_space() {
  local space="$1"
  local space_json display_id

  [ -x "$YABAI_BIN" ] || return 1

  space_json="$("$YABAI_BIN" -m query --spaces --space "$space" 2>/dev/null)" || return 1
  display_id="$(printf '%s' "$space_json" | jq -r '.display')"

  "$YABAI_BIN" -m query --windows --space "$space" 2>/dev/null | jq -r --argjson display "$display_id" --argjson space "$space" '
    map(
      select(
        .app
        and .space == $space
        and .display == $display
        and .role == "AXWindow"
        and .["has-ax-reference"] == true
        and .["is-minimized"] == false
        and .["is-hidden"] == false
        and (."is-sticky" // false) == false
      )
    )
    | sort_by(.frame.x, .frame.y, .["stack-index"], .id)
    | .[]
    | .app
  '
}

refresh_space() {
  local space="$1"
  local apps=""

  apps="$(apps_for_space "$space")" || true
  render_space "$space" "$apps"
}

case "${SENDER:-}" in
  space_windows_change)
    if [ -n "${INFO:-}" ]; then
      refresh_space "$(printf '%s' "$INFO" | jq -r '.space')"
      exit 0
    fi
    ;;
esac

for space in "${SPACE_IDS[@]}"
do
  refresh_space "$space"
done
