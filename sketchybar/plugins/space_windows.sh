#!/bin/bash

CONFIG_ROOT="${CONFIG_DIR:-$HOME/.config/sketchybar}"
YABAI_BIN="$(command -v "${YABAI_BIN:-yabai}" 2>/dev/null || true)"
JQ_BIN="$(command -v "${JQ_BIN:-jq}" 2>/dev/null || true)"
STATE_DIR="${SKETCHYBAR_STATE_DIR:-$CONFIG_ROOT/.state}"
SPACE_ITEM_STATE="$STATE_DIR/space_items"
CURRENT_SPACES=""

# shellcheck source=/dev/null
source "$CONFIG_ROOT/colors.sh"

# shellcheck source=/dev/null
source "$CONFIG_ROOT/plugins/icon_map.sh"

space_ids() {
  local ids=""

  if [ -n "$YABAI_BIN" ] && [ -n "$JQ_BIN" ]; then
    ids="$("$YABAI_BIN" -m query --spaces 2>/dev/null | "$JQ_BIN" -r '
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

  return 1
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
  local click_action=""

  if [ -n "$YABAI_BIN" ]; then
    printf -v click_action '%q -m space --focus %q' "$YABAI_BIN" "$sid"
  fi

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
    click_script="$click_action"
}

reconcile_spaces() {
  local force="${1:-}"
  local current_spaces desired_spaces known_spaces space drawing state_tmp

  mkdir -p "$STATE_DIR"
  known_spaces="$(cat "$SPACE_ITEM_STATE" 2>/dev/null || true)"

  # Keep the existing bar unchanged during a yabai restart. When yabai is not
  # installed, the rest of SketchyBar still works without ten dead Space items.
  if ! current_spaces="$(space_ids)"; then
    CURRENT_SPACES=""
    return 0
  fi

  CURRENT_SPACES="$current_spaces"
  desired_spaces="$current_spaces"

  while IFS= read -r space; do
    [ -n "$space" ] || continue

    if [ "$force" = "--force" ] || ! printf '%s\n' "$known_spaces" | list_contains "$space"; then
      add_space_item "$space"
    fi

    drawing=off
    if printf '%s\n' "$current_spaces" | list_contains "$space"; then
      drawing=on
    fi

    sketchybar --set "space.$space" drawing="$drawing" >/dev/null 2>&1 || true
  done <<< "$desired_spaces"

  # Hide items left behind when a high-numbered Space is removed.
  while IFS= read -r space; do
    [ -n "$space" ] || continue
    if ! printf '%s\n' "$desired_spaces" | list_contains "$space"; then
      sketchybar --set "space.$space" drawing=off >/dev/null 2>&1 || true
    fi
  done <<< "$known_spaces"

  state_tmp="$SPACE_ITEM_STATE.$$"
  printf '%s\n' "$desired_spaces" > "$state_tmp"
  mv "$state_tmp" "$SPACE_ITEM_STATE"
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
    icon_strip=" -"
  fi

  sketchybar --set "space.$space" label="$icon_strip"
}

apps_for_space() {
  local space="$1"
  local space_json display_id

  [ -n "$YABAI_BIN" ] && [ -n "$JQ_BIN" ] || return 1

  space_json="$("$YABAI_BIN" -m query --spaces --space "$space" 2>/dev/null)" || return 1
  display_id="$(printf '%s' "$space_json" | "$JQ_BIN" -r '.display')"

  "$YABAI_BIN" -m query --windows --space "$space" 2>/dev/null | "$JQ_BIN" -r --argjson display "$display_id" --argjson space "$space" '
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

refresh_current_spaces() {
  local space

  while IFS= read -r space; do
    [ -n "$space" ] || continue
    refresh_space "$space"
  done <<< "$CURRENT_SPACES"
}

case "${SENDER:-}" in
  space_windows_change)
    reconcile_spaces

    if [ -n "${INFO:-}" ] && [ -n "$JQ_BIN" ]; then
      changed_space="$(printf '%s' "$INFO" | "$JQ_BIN" -r '.space // empty' 2>/dev/null)"

      if printf '%s\n' "$CURRENT_SPACES" | list_contains "$changed_space"; then
        refresh_space "$changed_space"
      else
        refresh_current_spaces
      fi

    else
      refresh_current_spaces
    fi

    exit 0
    ;;
esac

case "${1:-}" in
  --reconcile)
    reconcile_spaces --force
    refresh_current_spaces
    exit 0
    ;;
  --space-ids)
    space_ids
    exit 0
    ;;
esac

reconcile_spaces
refresh_current_spaces
