#!/bin/bash
# Installs a local build into /Applications and runs setup. Setup backs up
# every file it replaces; `macarchy uninstall` puts them back.
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
/Applications/Macarchy.app/Contents/MacOS/macarchy doctor || true
