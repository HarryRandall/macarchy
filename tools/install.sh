#!/bin/bash
# Installs a local build into /Applications, runs setup and opens it. Setup
# backs up every file it replaces; `macarchy uninstall` puts them back.
set -Eeuo pipefail
cd "$(dirname "$0")/.."
APP=.build/artifacts/Macarchy.app
[ -d "$APP" ] || { echo 'Build first: ./tools/build.sh release' >&2; exit 1; }
if pgrep -x MacarchySettings >/dev/null; then
  echo 'Close the running Macarchy app before installing.' >&2
  exit 1
fi
rm -rf /Applications/Macarchy.app
cp -R "$APP" /Applications/Macarchy.app
/Applications/Macarchy.app/Contents/MacOS/macarchy setup "$@"
# Setup restarts SketchyBar, and the bar only keeps updating while the app
# runs, so it opens as soon as setup is done rather than after the health
# check. Not before setup: yabai restarts during setup, and an app still
# launching then is never managed by it.
open /Applications/Macarchy.app
/Applications/Macarchy.app/Contents/MacOS/macarchy doctor || true
