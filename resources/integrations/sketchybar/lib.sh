#!/bin/bash
# Shared by the bundled bar scripts. sketchybar runs plugins with launchd's
# minimal PATH, so every executable is located explicitly.

# A bar started by an earlier version can run these scripts through its app
# link before Macarchy has moved ~/.config/macarchy into Application Support.
# The scripts never create the new folder: Macarchy decides whether to move
# the old one, and an empty new folder must not look like one already moved.
MACARCHY_ROOT="$HOME/Library/Application Support/Macarchy"
if [ ! -d "$MACARCHY_ROOT" ] && [ -d "$HOME/.config/macarchy" ]; then
  MACARCHY_ROOT="$HOME/.config/macarchy"
fi
if [ -d "$MACARCHY_ROOT" ]; then
  MACARCHY_STATE="$MACARCHY_ROOT/state/bar"
else
  MACARCHY_STATE="${TMPDIR:-/tmp}/macarchy-bar-$UID"
fi
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
BAR_COLOR=0x01000000
COLOURS="$MACARCHY_ROOT/generated/bar-colours.sh"
# shellcheck source=/dev/null
[ -f "$COLOURS" ] && source "$COLOURS"
WARNING_COLOR=0xffffd60a
DANGER_COLOR=0xffff453a
export ACCENT_COLOR TEXT_COLOR BAR_COLOR WARNING_COLOR DANGER_COLOR
