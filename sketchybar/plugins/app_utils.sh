#!/usr/bin/env bash

get_front_app_name() {
  local front_spec=""
  local app_name=""

  if [ -n "${INFO:-}" ] && [ "${SENDER:-}" = "front_app_switched" ]; then
    printf '%s\n' "$INFO"
    return 0
  fi

  front_spec="$(lsappinfo front 2>/dev/null | sed 's/-/-0x/' || true)"
  case "$front_spec" in
    ""|"[ NULL ]")
      return 1
      ;;
  esac

  app_name="$(lsappinfo info -only name "$front_spec" 2>/dev/null | awk -F'"' 'NF >= 4 { print $4; exit }' || true)"
  [ -n "$app_name" ] || return 1
  printf '%s\n' "$app_name"
}

get_visible_app_names() {
  local raw_apps=""
  local parsed_apps=""

  raw_apps="$(lsappinfo visibleProcessList 2>/dev/null || true)"
  case "$raw_apps" in
    ""|"[ NULL ]")
      return 0
      ;;
  esac

  parsed_apps="$(printf '%s\n' "$raw_apps" | awk -F'"' '{ for (i = 2; i <= NF; i += 2) if ($i != "") print $i }')"
  if [ -n "$parsed_apps" ]; then
    printf '%s\n' "$parsed_apps"
    return 0
  fi

  printf '%s\n' "$raw_apps" | sed -n 's|.*\/\([^/]*\)\.app.*|\1|p'
}

filter_user_apps() {
  awk 'NF && !seen[$0]++' | while IFS= read -r app_name; do
    case "$app_name" in
      "Control Center"|"Notification Center"|"Dock"|"Window Server"|"SystemUIServer"|"loginwindow"|"SketchyBar")
        ;;
      *)
        printf '%s\n' "$app_name"
        ;;
    esac
  done
}

escape_single_quotes() {
  printf "%s" "$1" | sed "s/'/'\\\\''/g"
}
