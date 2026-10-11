#!/bin/bash
# Shared by the bundled bar scripts. sketchybar runs plugins with launchd's
# minimal PATH, so every executable is located explicitly.

MACARCHY_ROOT="$HOME/.config/macarchy"
MACARCHY_STATE="$MACARCHY_ROOT/state/bar"
mkdir -p "$MACARCHY_STATE"

# Prints the first executable found: Macarchy's own bin, Homebrew on Apple
# Silicon, Homebrew on Intel, then PATH.
macarchy_find() {
  local name="$1" dir
  for dir in "$MACARCHY_ROOT/bin" /opt/homebrew/bin /usr/local/bin; do
    if [ -x "$dir/$name" ]; then
      printf '%s\n' "$dir/$name"
      return 0
    fi
  done
  command -v "$name" 2>/dev/null || printf '%s\n' "/opt/homebrew/bin/$name"
}

# Theme colours, written by Macarchy whenever a theme is applied.
ACCENT_COLOR=0xffffffff
TEXT_COLOR=0xffffffff
BAR_COLOR=0x00000000
COLOURS="$MACARCHY_ROOT/generated/bar-colours.sh"
# shellcheck source=/dev/null
[ -f "$COLOURS" ] && source "$COLOURS"
WARNING_COLOR=0xffffd60a
DANGER_COLOR=0xffff453a
export ACCENT_COLOR TEXT_COLOR BAR_COLOR WARNING_COLOR DANGER_COLOR
