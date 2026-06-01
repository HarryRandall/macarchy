#!/bin/bash

CONFIG_ROOT="${CONFIG_DIR:-$HOME/.config/sketchybar}"
YABAI_BIN="${YABAI_BIN:-$(command -v yabai 2>/dev/null || true)}"
[ -x "$YABAI_BIN" ] || YABAI_BIN="/opt/homebrew/bin/yabai"
STATE_DIR="$CONFIG_ROOT/.state"
SPACE_ITEM_STATE="$STATE_DIR/space_items"
MAX_FALLBACK_SPACES="${MAX_FALLBACK_SPACES:-10}"

# shellcheck source=/dev/null
source "$CONFIG_ROOT/colors.sh"

# shellcheck source=/dev/null
source "$CONFIG_ROOT/plugins/icon_map.sh"

space_ids() {
  local ids=""

  if [ -x "$YABAI_BIN" ]; then
    ids="$("$YABAI_BIN" -m query --spaces 2>/dev/null | jq -r '
      sort_by(.index)
      | .[]
      | select(.index != null)
      | .index
    ' 2>/dev/null)" || ids=""
  fi

  if [ -n "$ids" ]; then
    printf '%s\n' "$ids"
    return 0
  fi

  local space=1
  while [ "$space" -le "$MAX_FALLBACK_SPACES" ]; do
    printf '%s\n' "$space"
    space=$((space + 1))
  done
}

list_contains() {
  local needle="$1"
  local item

  while IFS= read -r item; do
    [ "$item" = "$needle" ] && return 0
  done

  return 1
}

add_space_item() {
  local sid="$1"

  sketchybar --add space "space.$sid" left >/dev/null 2>&1 || true

  sketchybar --set "space.$sid" \
    space="$sid" \
    icon="$sid" \
    icon.font="SF Pro:Semibold:12.0" \
    icon.color="${TEXT_COLOR:-0xffffffff}" \
    padding_left=2 \
    label="" \
    label.font="sketchybar-app-font:Regular:13.0" \
    label.color="${TEXT_COLOR:-0xffffffff}" \
    label.padding_right=20 \
    label.y_offset=-1 \
    background.drawing=off \
    background.border_width=0 \
    background.border_color=0x00000000 \
    background.color=0x00000000 \
    script="$CONFIG_ROOT/plugins/space.sh" \
    click_script="$YABAI_BIN -m space --focus $sid"
}

reconcile_spaces() {
  local force="${1:-}"
  local current_spaces desired_spaces space drawing

  mkdir -p "$STATE_DIR"
  current_spaces="$(space_ids)"
  desired_spaces="$(space_ids | awk -v max="$MAX_FALLBACK_SPACES" '
    { seen[$0] = 1 }
    END {
      for (i = 1; i <= max; i++) seen[i] = 1
      for (space in seen) print space
    }
  ' | LC_ALL=C sort -n)"

  while IFS= read -r space; do
    [ -n "$space" ] || continue

    if [ "$force" = "--force" ]; then
      add_space_item "$space"
    fi

    drawing=off
    if printf '%s\n' "$current_spaces" | list_contains "$space"; then
      drawing=on
    fi

    sketchybar --set "space.$space" drawing="$drawing" >/dev/null 2>&1 || true
  done <<< "$desired_spaces"

  while IFS= read -r space; do
    [ -n "$space" ] || continue
    refresh_space "$space"
  done <<< "$current_spaces"

  printf '%s\n' "$current_spaces" > "$SPACE_ITEM_STATE"
}

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

  case "$space" in
    ''|*[!0-9]*|0)
      return 0
      ;;
  esac

  apps="$(apps_for_space "$space")" || true
  render_space "$space" "$apps"
}

case "${SENDER:-}" in
  space_windows_change)
    reconcile_spaces

    if [ -n "${INFO:-}" ]; then
      changed_space="$(printf '%s' "$INFO" | jq -r '.space // empty')"

      if printf '%s\n' "$(space_ids)" | list_contains "$changed_space"; then
        refresh_space "$changed_space"
      else
        while IFS= read -r space; do
          [ -n "$space" ] || continue
          refresh_space "$space"
        done <<< "$(space_ids)"
      fi

      exit 0
    fi
    ;;
esac

case "${1:-}" in
  --reconcile)
    reconcile_spaces --force
    exit 0
    ;;
  --space-ids)
    space_ids
    exit 0
    ;;
esac

reconcile_spaces

while IFS= read -r space
do
  [ -n "$space" ] || continue
  refresh_space "$space"
done <<< "$(space_ids)"
