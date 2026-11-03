#!/bin/bash
# Bundled with Macarchy for the default shortcuts. Opens a new Ghostty window,
# tiled and focused, or a Terminal window when Ghostty is not installed.
set -uo pipefail

if ! command -v yabai >/dev/null || ! command -v jq >/dev/null; then
  open -na Ghostty 2>/dev/null || open -na Terminal
  exit
fi

# yabai tiles a new window by splitting the focused one, and quick presses open
# windows before the last one has focus. So presses share a chain: while any
# press waits, new Ghostty windows open floating, and each is tiled in the
# order it opened, splitting the one before it. The first splits whatever had
# focus at the first press. The state file holds the presses still waiting,
# the newest window placed and the window the next one splits.
state="${TMPDIR:-/tmp}/macarchy-launch-ghostty"
lock="$state.lock"
rule=macarchy-launch-ghostty

age() { echo $(( $(date +%s) - $(stat -f %m "$1" 2>/dev/null || date +%s) )); }

take_lock() {
  until mkdir "$lock" 2>/dev/null; do
    # No run holds the lock this long, so one that was killed left it.
    [ "$(age "$lock")" -gt 5 ] && rmdir "$lock" 2>/dev/null
    sleep 0.02
  done
}

read_state() {
  pending=0 newest=0 anchor=0
  # An old chain belongs to presses that gave up, so start a new one.
  [ -f "$state" ] && [ "$(age "$state")" -le 5 ] \
    && read -r pending newest anchor < "$state"
}

write_state() {
  echo "$pending $newest $anchor" > "$state"
  [ "$pending" -le 0 ] && yabai -m rule --remove "$rule" 2>/dev/null
}

ghostty_ids='map(select(.app == "Ghostty")) | map(.id) | sort'

take_lock
read_state
if [ "$pending" -le 0 ]; then
  pending=0
  anchor="$(yabai -m query --windows --window 2>/dev/null | jq -r '.id // 0')"
  newest="$(yabai -m query --windows 2>/dev/null | jq -r "$ghostty_ids | last // 0")"
  yabai -m rule --add label="$rule" app='^Ghostty$' manage=off
fi
pending=$((pending + 1))
write_state
rmdir "$lock"

if ! open -na Ghostty 2>/dev/null; then
  take_lock; read_state; pending=$((pending - 1)); write_state; rmdir "$lock"
  open -na Terminal
  exit
fi

place() {
  local window="$1" target
  target="$(yabai -m query --windows --window "$anchor" 2>/dev/null \
    | jq -r --argjson space "$(yabai -m query --windows --window "$window" | jq .space)" \
      'select(.space == $space and ."is-floating" == false and ."is-visible") | .id' 2>/dev/null)"
  if [ -n "$target" ]; then
    yabai -m window --focus "$target"
    # Focus lands a moment after the command returns.
    for _ in $(seq 1 20); do
      [ "$(yabai -m query --windows --window 2>/dev/null | jq -r '.id')" = "$target" ] && break
      sleep 0.01
    done
  fi
  if [ "$(yabai -m query --windows --window "$window" 2>/dev/null | jq -r '."is-floating"')" = true ]; then
    yabai -m window "$window" --toggle float
  fi
  yabai -m window --focus "$window" 2>/dev/null || true
}

# Ghostty can take seconds to open several windows at once.
for _ in $(seq 1 120); do
  sleep 0.05
  take_lock
  read_state
  for window in $(yabai -m query --windows 2>/dev/null \
    | jq -r --argjson newest "$newest" "$ghostty_ids | map(select(. > \$newest)) | .[]"); do
    place "$window"
    newest="$window" anchor="$window" pending=$((pending - 1))
  done
  write_state
  rmdir "$lock"
  [ "$pending" -le 0 ] && exit
done

# This press's window never came, so stop waiting for it.
take_lock; read_state; pending=$((pending - 1)); write_state; rmdir "$lock"
