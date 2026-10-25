#!/usr/bin/env bash
set -euo pipefail

YABAI_BIN="${YABAI_BIN:-$(command -v yabai 2>/dev/null || true)}"
[ -x "$YABAI_BIN" ] || YABAI_BIN="/opt/homebrew/bin/yabai"
[ -x "$YABAI_BIN" ] || exit 1
command -v jq >/dev/null 2>&1 || exit 1

front_app="$(
  /usr/bin/osascript -e 'tell application "System Events" to name of first application process whose frontmost is true' 2>/dev/null \
    | tr '[:upper:]' '[:lower:]'
)"
[ "$front_app" = "firefox" ] || exit 1

windows_json="$("$YABAI_BIN" -m query --windows 2>/dev/null || true)"
[ -n "$windows_json" ] || exit 1

selector_ids="$(
  jq -r '
    map(
      select(
        ((.app // "" | ascii_downcase) == "firefox")
        and .title == "Firefox - Choose a profile"
        and ."is-minimized" != true
        and ."is-hidden" != true
      )
    )
    | .[].id
  ' <<<"$windows_json"
)"

[ -n "$selector_ids" ] || exit 1

while IFS= read -r window_id; do
  [ -n "$window_id" ] || continue
  "$YABAI_BIN" -m window "$window_id" --close >/dev/null 2>&1 || true
done <<<"$selector_ids"
