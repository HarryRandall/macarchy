#!/bin/bash
# Build and launch, replacing any running copy.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/tools/build.sh" "${1:-debug}"
pkill -x MacarchySettings 2>/dev/null || true
# Wait for the old process to exit before asking Launch Services to reopen it.
for attempt in {1..40}; do
  if ! pgrep -x MacarchySettings >/dev/null; then break; fi
  sleep 0.1
done
if pgrep -x MacarchySettings >/dev/null; then
  echo 'The previous app is still closing. Open the built app when it has exited.' >&2
  exit 1
fi
# Keep the development app on its desktop without moving the user's focus.
if YABAI="$(command -v yabai)"; then
  "$YABAI" -m rule --remove macarchy_workspace 2>/dev/null || true
  "$YABAI" -m rule --add label=macarchy_workspace app='^Macarchy$' space=3 manage=off grid=10:10:1:1:8:8
fi
open -g "$ROOT/.build/artifacts/Macarchy.app"
