#!/bin/bash
# Assemble the package into a signed .app bundle.
#
# Signing uses a self-signed Keychain identity rather than ad-hoc: an ad-hoc
# signature changes on every rebuild, so macOS treats each build as a new app
# and drops any permission it was granted. Set MACARCHY_SIGN_IDENTITY to the
# name of a "Code Signing" certificate created in Keychain Access; without it
# the script falls back to ad-hoc and says so.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Macarchy"
BINARY="MacarchySettings"
CONFIG="${1:-release}"
DIST="$ROOT/.build/artifacts"
APP="$DIST/$APP_NAME.app"

echo "==> Building ($CONFIG)"
cd "$ROOT"
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)/$BINARY"
[ -f "$BIN_PATH" ] || { echo "error: binary not found at $BIN_PATH" >&2; exit 1; }

echo "==> Assembling bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH" "$APP/Contents/MacOS/$BINARY"
cp "$ROOT/macarchy/app/resources/Info.plist" "$APP/Contents/Info.plist"
[ -f "$ROOT/macarchy/app/resources/AppIcon.icns" ] && cp "$ROOT/macarchy/app/resources/AppIcon.icns" "$APP/Contents/Resources/"

# Themes, the starter bar and default shortcuts. The command line tool ships
# inside the app, so one bundle is the whole install.
cp -R "$ROOT/macarchy/resources/." "$APP/Contents/Resources/"
CLI_PATH="$(swift build -c "$CONFIG" --show-bin-path)/macarchy"
cp "$CLI_PATH" "$APP/Contents/MacOS/macarchy"
echo "    bundled $(find "$ROOT/macarchy/resources/themes" -name theme.json | wc -l | tr -d ' ') themes, the menu bar and default shortcuts"

echo "==> Signing"
IDENTITY="${MACARCHY_SIGN_IDENTITY:-}"
if [ -n "$IDENTITY" ]; then
  codesign --force --options runtime --sign "$IDENTITY" "$APP/Contents/MacOS/macarchy"
  codesign --force --deep --options runtime --sign "$IDENTITY" "$APP"
  echo "    signed as: $IDENTITY"
else
  codesign --force --sign - "$APP/Contents/MacOS/macarchy"
  codesign --force --deep --sign - "$APP"
  echo "    signed ad-hoc — permissions will reset on each rebuild."
  echo "    Create a self-signed cert in Keychain Access and export"
  echo "    MACARCHY_SIGN_IDENTITY=\"<cert name>\" to keep a stable identity."
fi

echo "==> Built: $APP (not installed)"
