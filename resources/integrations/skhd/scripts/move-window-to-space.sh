#!/bin/bash
# Kept for shortcuts files written before `macarchy space <number> --move`,
# which moves the focused window to a Space and follows it there. New files
# call that directly: move-window-to-space.sh <number>
set -uo pipefail
target="${1:-}"
case "$target" in
  '' | *[!0-9]* | 0) exit 64 ;;
esac

# This script ships in Macarchy.app/Contents/Resources/skhd/scripts.
macarchy="$(dirname "$0")/../../../MacOS/macarchy"
[ -x "$macarchy" ] || macarchy=macarchy
exec "$macarchy" space "$target" --move
