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
APP_NAME="Macarchy Settings"
BINARY="MacarchySettings"
CONFIG="${1:-release}"
DIST="$ROOT/dist"
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
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
[ -f "$ROOT/Resources/AppIcon.icns" ] && cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/"

# Shipped theme defaults, used as the reset-to-default baseline.
if [ -d "$ROOT/Themes" ]; then
  cp -R "$ROOT/Themes" "$APP/Contents/Resources/Themes"
  echo "    bundled $(find "$ROOT/Themes" -name theme.json | wc -l | tr -d ' ') default themes"
fi

echo "==> Signing"
IDENTITY="${MACARCHY_SIGN_IDENTITY:-}"
if [ -n "$IDENTITY" ]; then
  codesign --force --deep --options runtime --sign "$IDENTITY" "$APP"
  echo "    signed as: $IDENTITY"
else
  codesign --force --deep --sign - "$APP"
  echo "    signed ad-hoc — permissions will reset on each rebuild."
  echo "    Create a self-signed cert in Keychain Access and export"
  echo "    MACARCHY_SIGN_IDENTITY=\"<cert name>\" to keep a stable identity."
fi

# The CLI is how ported surfaces stay single-implementation: theme-switch and
# the theme-cycling hotkey call it, so the keyboard path and the GUI path run
# the same code.
CLI_PATH="$(swift build -c "$CONFIG" --show-bin-path)/macarchy"
if [ -f "$CLI_PATH" ]; then
  mkdir -p "$HOME/.local/bin"
  cp "$CLI_PATH" "$HOME/.local/bin/macarchy"
  echo "==> Installed CLI: ~/.local/bin/macarchy"
fi

echo "==> Done: $APP"
