#!/usr/bin/env bash
set -euo pipefail

YABAI_BIN="${YABAI_BIN:-$(command -v yabai 2>/dev/null || true)}"
[ -x "$YABAI_BIN" ] || YABAI_BIN="/opt/homebrew/bin/yabai"

JQ_BIN="${JQ_BIN:-$(command -v jq 2>/dev/null || true)}"
[ -x "$JQ_BIN" ] || JQ_BIN="/opt/homebrew/bin/jq"

OSASCRIPT="/usr/bin/osascript"

quit_frontmost_app() {
  "$OSASCRIPT" -e 'tell application (path to frontmost application as text) to quit'
}

quit_app_by_pid() {
  local pid="$1"
  [ -n "$pid" ] || return 1

  "$OSASCRIPT" -l JavaScript - "$pid" <<'JXA'
function run(argv) {
  ObjC.import('AppKit');

  const pid = Number(argv[0]);
  const app = $.NSRunningApplication.runningApplicationWithProcessIdentifier(pid);

  if (!app) {
    throw new Error('No running application for pid ' + pid);
  }

  // JXA exposes this zero-argument Objective-C method as a property. Reading
  // it sends the terminate message and returns the Boolean result.
  if (!app.terminate) {
    throw new Error('Terminate request failed for pid ' + pid);
  }
}
JXA
}

close_focused_window() {
  local window_id="$1"
  [ -n "$window_id" ] || return 1

  "$YABAI_BIN" -m window "$window_id" --close
}

if [ ! -x "$YABAI_BIN" ] || [ ! -x "$JQ_BIN" ]; then
  quit_frontmost_app
  exit 0
fi

window_json="$("$YABAI_BIN" -m query --windows --window 2>/dev/null || true)"

if ! "$JQ_BIN" -e 'type == "object" and (.id? != null)' >/dev/null 2>&1 <<<"$window_json"; then
  quit_frontmost_app
  exit 0
fi

app_name="$("$JQ_BIN" -r '.app // empty' <<<"$window_json")"
window_id="$("$JQ_BIN" -r '.id // empty' <<<"$window_json")"
pid="$("$JQ_BIN" -r '.pid // empty' <<<"$window_json")"

# Hand focus to another window on this space BEFORE quitting, so macOS
# never activates an app from another space (which would switch to it).
# Must be a different app: same-app windows die with the quit.
sibling_id="$("$YABAI_BIN" -m query --windows --space 2>/dev/null | "$JQ_BIN" -r --arg pid "$pid" '
  [.[] | select((.pid | tostring) != $pid and ."is-minimized" != true and ."is-hidden" != true)]
  | first | .id // empty' || true)"

if [ -n "$sibling_id" ]; then
  "$YABAI_BIN" -m window --focus "$sibling_id" 2>/dev/null || true
fi

case "$app_name" in
  "Google Chrome"|"Brave Browser"|"Finder")
    close_focused_window "$window_id" || true
    exit 0
    ;;
esac

if ! quit_app_by_pid "$pid"; then
  close_focused_window "$window_id" || true
fi
