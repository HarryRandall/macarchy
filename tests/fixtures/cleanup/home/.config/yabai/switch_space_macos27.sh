#!/bin/bash
set -euo pipefail

# TEMPORARY macOS 27 workaround, installed 2026-09-16.
# InstantSpaceSwitcher PR #88, commit c64e0fd, built locally for macOS 27.
# Replace with native yabai Space switching once a compatible release is
# available and verified locally, including empty Spaces and move-and-follow.
# Update the Cmd/Ctrl number bindings in ~/.config/skhd/skhdrc at that point.
# Original config: ~/.config/skhd/skhdrc.backup-20260916-214738
YABAI=/opt/homebrew/bin/yabai
JQ=/opt/homebrew/bin/jq
ISS="$HOME/.local/share/InstantSpaceSwitcher/build/InstantSpaceSwitcher.app/Contents/MacOS/ISSCli"
target="${1:-}"
case "$target" in
  ''|*[!0-9]*) exit 64 ;;
  0) exit 64 ;;
esac

# Validate first: ISS otherwise clamps missing destinations to the last Space.
# A Space that does not exist yet is a silent no-op, so bindings for Spaces
# you have not created simply do nothing and start working once you add them.
"$YABAI" -m query --spaces --space "$target" >/dev/null 2>&1 || exit 0
window_id=""
if [[ "${2:-}" == move ]]; then
  # No focused window (empty Space, unmanaged window) must still switch.
  window_id="$("$YABAI" -m query --windows --window 2>/dev/null | "$JQ" -r '.id // empty' 2>/dev/null || true)"
  if [[ -n "$window_id" ]]; then
    "$YABAI" -m window "$window_id" --space "$target" 2>/dev/null || window_id=""
  fi
fi

"$ISS" index "$target"
if [[ -n "$window_id" ]]; then
  "$YABAI" -m window --focus "$window_id"
fi
