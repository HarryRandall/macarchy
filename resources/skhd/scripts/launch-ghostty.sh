#!/bin/bash
# Bundled with Macarchy for the default shortcuts. Opens a new Ghostty window,
# or a Terminal window when Ghostty is not installed.
#
# The window comes from the running Ghostty rather than a new copy of it.
# yabai tiles a window from a running app at window_insertion_point, but the
# first window of a newly launched app splits whichever window has focus, so
# launching a copy per press tiled quick presses out of order.
set -uo pipefail

# Scripting an app that is missing asks where it is, so check first.
[ -d /Applications/Ghostty.app ] || [ -d "$HOME/Applications/Ghostty.app" ] \
  || exec open -na Terminal

launching="${TMPDIR:-/tmp}/macarchy-launch-ghostty"
running() { pgrep -qf 'Ghostty.app/Contents/MacOS/ghostty'; }
age() { echo $(( $(date +%s) - $(stat -f %m "$1" 2>/dev/null || date +%s) )); }

# A launch that was killed leaves its marker behind.
[ -d "$launching" ] && [ "$(age "$launching")" -gt 5 ] && rmdir "$launching" 2>/dev/null

if ! running && mkdir "$launching" 2>/dev/null; then
  open -a Ghostty
  # Presses during the launch wait for its first window, then open their own.
  for _ in $(seq 1 50); do
    [ "$(osascript -e 'tell application "Ghostty" to count windows' 2>/dev/null)" -gt 0 ] 2>/dev/null \
      && break
    sleep 0.1
  done
  rmdir "$launching"
  exit
fi

for _ in $(seq 1 100); do
  [ -d "$launching" ] || break
  sleep 0.05
done
osascript -e 'tell application "Ghostty"' -e 'new window' -e 'activate' -e 'end tell' >/dev/null
