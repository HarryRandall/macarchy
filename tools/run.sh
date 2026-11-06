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
# Macarchy's own bin folder: the app looks there before Homebrew, so nothing
# reaches the real daemons.
BIN="$HOME_DIR/Library/Application Support/Macarchy/bin"

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
cp -R "$ROOT/resources/themes" "$HOME_DIR/Library/Application Support/Macarchy/themes"
# An existing file means setup is not offered.
cat >"$HOME_DIR/Library/Application Support/Macarchy/settings.json" <<'JSON'
{
  "schema": 1, "currentTheme": null, "wallpapers": {}, "layout": {}, "borders": {},
  "menuBar": {}, "floatingApps": [], "windowRules": null, "barConfiguration": null,
  "itemOrder": [], "itemVisibility": {}, "itemLabels": {}
}
JSON
for tool in yabai skhd sketchybar borders; do
  printf '#!/bin/sh\nexit 0\n' >"$BIN/$tool"
  chmod +x "$BIN/$tool"
done

# launchctl and defaults act on the login session and the global domain
# whatever HOME says, and the app only looks for them on its search path.
# This launchctl records each call and reports every job as running.
cat >"$BIN/launchctl" <<SH
#!/bin/sh
printf '%s\n' "\$*" >>'$HOME_DIR/launchctl.log'
case "\$1" in
  print) printf 'state = running\npid = 4242\n' ;;
  kickstart | kill | list | bootstrap | bootout) ;;
  *) echo "The development launchctl does not support \$1." >&2; exit 1 ;;
esac
SH

# Global values live in a file in the temporary home, one KEY=VALUE per line,
# with the real tool's messages and exit codes for the calls the app makes.
cat >"$BIN/defaults" <<SH
#!/bin/sh
store='$HOME_DIR/global-defaults'
touch "\$store"
if [ "\$2" != -g ]; then
  echo "The development defaults only supports the global domain." >&2
  exit 1
fi
key="\$3"
others() { awk -v k="\$key" 'index(\$0, k "=") != 1' "\$store"; }
case "\$1 \$#" in
  "read 3")
    if ! awk -v k="\$key" 'index(\$0, k "=") == 1 { v = substr(\$0, length(k) + 2); f = 1 }
      END { if (f) print v; exit !f }' "\$store"; then
      printf '\nThe domain/default pair of (kCFPreferencesAnyApplication, %s) does not exist\n' \\
        "\$key" >&2
      exit 1
    fi
    ;;
  "write 5")
    [ "\$4" = -float ] || { echo "The development defaults only writes -float." >&2; exit 1; }
    value="\$(awk -v v="\$5" 'BEGIN { print v + 0 }')"
    { others; echo "\$key=\$value"; } >"\$store.new" && mv "\$store.new" "\$store"
    ;;
  "delete 3")
    if ! awk -v k="\$key" 'index(\$0, k "=") == 1 { f = 1 } END { exit !f }' "\$store"; then
      printf 'Domain (kCFPreferencesAnyApplication) not found.\nDefaults have not been changed.\n' >&2
      exit 1
    fi
    others >"\$store.new" && mv "\$store.new" "\$store"
    ;;
  *)
    echo "The development defaults does not support: \$*" >&2
    exit 1
    ;;
esac
SH
chmod +x "$BIN/launchctl" "$BIN/defaults"

# open cannot report the PID it starts, so the new one is whichever copy of
# this build was not already running. HOME keeps anything that reads it, such
# as a widget's script, in the temporary home.
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
