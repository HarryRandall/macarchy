#!/bin/bash
# Build a debug copy and open it beside the installed app, in a throwaway home
# with fake daemons, so development never changes the live desktop or install.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/.build/artifacts/Macarchy.app"
EXE="$APP/Contents/MacOS/MacarchySettings"
# One folder per checkout, so worktrees never stop each other's copies.
RUN="${TMPDIR:-/tmp}/macarchy-run-$(printf %s "$ROOT" | cksum | cut -d' ' -f1)"
HOME_DIR="$RUN/home"
# Macarchy's own bin folder: the app and the bundled bar scripts both look
# there before Homebrew, so nothing reaches the real daemons.
BIN="$HOME_DIR/.config/macarchy/bin"

# PIDs of processes running this build's executable.
copies() {
  ps -axo pid=,command= |
    awk -v exe="$EXE" '{ pid = $1; sub(/^ *[0-9]+ +/, ""); if (index($0, exe) == 1) print pid }'
}

# Stop the copy this script started last time, and only if that PID still
# runs this build: PIDs are reused, and an installed copy must stay untouched.
# This happens before building, which replaces the bundle it runs from.
if [ -f "$RUN/pid" ]; then
  pid="$(cat "$RUN/pid")"
  # Not grep -q: exiting early would fail the pipeline under pipefail.
  if copies | grep -xF "$pid" >/dev/null; then
    kill "$pid" 2>/dev/null || true
    for _ in {1..50}; do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
    if kill -0 "$pid" 2>/dev/null; then
      echo "The previous development copy ($pid) is still closing. Try again shortly." >&2
      exit 1
    fi
  fi
fi

# Debug only: release builds ignore the dry-run and shortcut variables below.
"$ROOT/tools/build.sh" debug

rm -rf "$RUN"
mkdir -p "$BIN"
cp -R "$ROOT/resources/themes" "$HOME_DIR/.config/macarchy/themes"
# Every key, since settings without one fail to decode. An existing file also
# means setup is not offered.
cat >"$HOME_DIR/.config/macarchy/settings.json" <<'JSON'
{
  "schema": 1, "currentTheme": null, "wallpapers": {}, "layout": {}, "borders": {},
  "menuBar": {}, "floatingApps": [], "windowRules": null, "barConfiguration": null,
  "itemOrder": [], "itemVisibility": {}, "itemLabels": {}, "bundledBar": null
}
JSON
for tool in yabai skhd sketchybar borders; do
  printf '#!/bin/sh\nexit 0\n' >"$BIN/$tool"
  chmod +x "$BIN/$tool"
done

# open cannot report the PID it starts, so the new one is whichever copy of
# this build was not already running. HOME reaches the bundled bar scripts,
# which find their tools through it.
before="$(copies)"
open -n \
  --env MACARCHY_HOME="$HOME_DIR" \
  --env HOME="$HOME_DIR" \
  --env MACARCHY_SEARCH_PATH="$BIN" \
  --env MACARCHY_DEBUG_NO_SHORTCUT=1 \
  --env MACARCHY_DEBUG_DRY_THEMES=1 \
  "$APP"
for _ in {1..50}; do
  pid="$(copies | grep -vxF "$before" | head -n 1 || true)"
  if [ -n "$pid" ]; then
    echo "$pid" >"$RUN/pid"
    echo "Started PID $pid with its home in $HOME_DIR"
    exit 0
  fi
  sleep 0.1
done
echo 'The app opened but its PID was not found, so the next run will not stop it.' >&2
