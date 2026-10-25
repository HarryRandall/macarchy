#!/bin/bash
set -euo pipefail

# Cycle to the previous/next Space on the current display.
#
# The Space list is queried live on every invocation, so adding or removing
# Spaces in Mission Control takes effect immediately with no skhdrc edit.
# Wraps at both ends. Uses InstantSpaceSwitcher for the same reason
# switch_space_macos27.sh does: native `yabai -m space --focus` silently
# no-ops on macOS 27 (returns success, does not switch).

YABAI=/opt/homebrew/bin/yabai
JQ=/opt/homebrew/bin/jq
ISS="$HOME/.local/share/InstantSpaceSwitcher/build/InstantSpaceSwitcher.app/Contents/MacOS/ISSCli"

dir="${1:-}"
case "$dir" in
  next|prev) ;;
  *) exit 64 ;;
esac

current="$("$YABAI" -m query --spaces --space 2>/dev/null || true)"
[ -n "$current" ] || exit 0

cur_index="$("$JQ" -r '.index // empty' <<<"$current")"
cur_display="$("$JQ" -r '.display // empty' <<<"$current")"
[ -n "$cur_index" ] && [ -n "$cur_display" ] || exit 0

# jq does the wrap arithmetic so this stays bash 3.2 compatible (no mapfile).
target="$(
  "$YABAI" -m query --spaces 2>/dev/null | "$JQ" -r \
    --argjson d "$cur_display" --argjson c "$cur_index" --arg dir "$dir" '
      ([ .[] | select(.display == $d) | .index ] | sort) as $ix
      | ($ix | length) as $n
      | ($ix | index($c)) as $pos
      | if $pos == null or $n < 2 then empty
        elif $dir == "next" then $ix[($pos + 1) % $n]
        else $ix[($pos - 1 + $n) % $n]
        end
    ' 2>/dev/null || true
)"

[ -n "$target" ] || exit 0
exec "$ISS" index "$target"
