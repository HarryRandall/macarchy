#!/usr/bin/env bash

set -euo pipefail

YABAI_BIN="$(command -v "${YABAI_BIN:-yabai}" 2>/dev/null || true)"
JQ_BIN="$(command -v "${JQ_BIN:-jq}" 2>/dev/null || true)"
[ -n "$YABAI_BIN" ] && [ -n "$JQ_BIN" ] || exit 0

# Record existing Ghostty windows before launching. Picking the highest window
# ID after a fixed sleep can focus an older window when startup is slow.
before_ids="$("$YABAI_BIN" -m query --windows 2>/dev/null \
  | "$JQ_BIN" -c '[.[] | select(.app == "Ghostty") | .id]' 2>/dev/null)" || exit 0

open -na Ghostty

attempts="${GHOSTTY_WINDOW_POLL_ATTEMPTS:-30}"
delay="${GHOSTTY_WINDOW_POLL_DELAY:-0.1}"
case "$attempts" in
  ''|*[!0-9]*|0) attempts=30 ;;
esac
case "$delay" in
  ''|.|*[!0-9.]*|*.*.*) delay=0.1 ;;
esac

id=""
while [ "$attempts" -gt 0 ]; do
  windows_json="$("$YABAI_BIN" -m query --windows 2>/dev/null || printf '[]\n')"
  id="$(
    "$JQ_BIN" -r --argjson before "$before_ids" '
      map(
        select(
          .app == "Ghostty"
          and (.id as $id | ($before | index($id)) == null)
        )
      )
      | sort_by(.id)
      | last.id // empty
    ' <<<"$windows_json" 2>/dev/null || true
  )"
  [ -n "$id" ] && break

  attempts=$((attempts - 1))
  [ "$attempts" -gt 0 ] && sleep "$delay"
done

[[ -n "$id" ]] || exit 0

is_floating="$("$YABAI_BIN" -m query --windows --window "$id" 2>/dev/null | "$JQ_BIN" -r '."is-floating" // false')"
if [[ "$is_floating" == "true" ]]; then
  "$YABAI_BIN" -m window "$id" --toggle float
fi

"$YABAI_BIN" -m window --focus "$id" 2>/dev/null || true
