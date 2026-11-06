#!/bin/bash
# Bundled with Macarchy for the default shortcuts. Quits the app that owns the
# window yabai has focused, which is not always the app macOS calls frontmost.
# Browsers and Finder close only that window.
set -uo pipefail

quit_frontmost() {
  osascript -e 'tell application (path to frontmost application as text) to quit'
}

if ! command -v yabai >/dev/null || ! command -v jq >/dev/null; then
  quit_frontmost
  exit
fi

window_json="$(yabai -m query --windows --window 2>/dev/null)"
if ! jq -e 'type == "object" and .id != null' >/dev/null 2>&1 <<<"$window_json"; then
  quit_frontmost
  exit
fi
app="$(jq -r '.app // empty' <<<"$window_json")"
window="$(jq -r '.id' <<<"$window_json")"
pid="$(jq -r '.pid // empty' <<<"$window_json")"

# Focus another app's window on this Space before quitting, so macOS does not
# activate an app on another Space and switch to it. The app's own windows
# close with it.
sibling="$(yabai -m query --windows --space 2>/dev/null | jq -r --arg pid "$pid" '
  [.[] | select((.pid | tostring) != $pid and ."is-minimized" != true and ."is-hidden" != true)]
  | first | .id // empty' 2>/dev/null)"
if [ -n "$sibling" ]; then
  yabai -m window --focus "$sibling" 2>/dev/null || true
fi

case "$app" in
  "Google Chrome" | "Brave Browser" | "Finder")
    yabai -m window "$window" --close 2>/dev/null
    exit 0
    ;;
esac

# Asks the app to terminate by process id, as Command-Q would. Unlike telling
# the app to quit by name, this needs no Automation permission.
terminate() {
  osascript -l JavaScript - "$1" <<'JXA'
function run(argv) {
  ObjC.import('AppKit');
  const app = $.NSRunningApplication.runningApplicationWithProcessIdentifier(Number(argv[0]));
  // JXA exposes this zero-argument method as a property; reading it sends
  // terminate and returns whether the request was made.
  if (!app || !app.terminate) throw new Error('Could not ask ' + argv[0] + ' to quit');
}
JXA
}

if [ -z "$pid" ] || ! terminate "$pid" >/dev/null 2>&1; then
  yabai -m window "$window" --close 2>/dev/null || true
fi
