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

echo "==> Building the interface"
# The interface is built here and bundled; the app itself never needs Node or
# a development server.
UI="$ROOT/src/desktop/ui"
command -v node >/dev/null || { echo "error: Node.js 22.12 or later is required to build the interface" >&2; exit 1; }
# Node 25 stopped shipping corepack, so a pnpm on PATH, such as Homebrew's,
# stands in for it there.
if command -v corepack >/dev/null; then
  PNPM=(corepack pnpm)
elif command -v pnpm >/dev/null; then
  PNPM=(pnpm)
else
  echo "error: pnpm is required to build the interface: brew install pnpm, or use Node 22 or 24, which include corepack" >&2
  exit 1
fi
(cd "$UI" && "${PNPM[@]}" install --frozen-lockfile && "${PNPM[@]}" run build)

echo "==> Building ($CONFIG)"
cd "$ROOT"
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)/$BINARY"
[ -f "$BIN_PATH" ] || { echo "error: binary not found at $BIN_PATH" >&2; exit 1; }

echo "==> Assembling bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH" "$APP/Contents/MacOS/$BINARY"
cp "$ROOT/packaging/macos/Info.plist" "$APP/Contents/Info.plist"
[ -f "$ROOT/resources/app/AppIcon.icns" ] && cp "$ROOT/resources/app/AppIcon.icns" "$APP/Contents/Resources/"

# Themes, the starter bar, built-in widgets and default shortcuts. The command
# line tool ships inside the app, so one bundle is the whole install.
cp "$ROOT/resources/app/logo.svg" "$APP/Contents/Resources/"
cp -R "$ROOT/resources/themes" "$ROOT/resources/widgets" "$ROOT/resources/integrations/sketchybar" \
  "$ROOT/resources/integrations/skhd" "$APP/Contents/Resources/"
cp -R "$ROOT/resources/plugins" "$ROOT/resources/launchers" "$APP/Contents/Resources/"
cp "$ROOT/resources/plugins/neovim/nvim" "$APP/Contents/MacOS/nvim"
cp -R "$UI/dist" "$APP/Contents/Resources/ui"
CLI_PATH="$(swift build -c "$CONFIG" --show-bin-path)/macarchy"
cp "$CLI_PATH" "$APP/Contents/MacOS/macarchy"
echo "    bundled $(find "$ROOT/resources/themes" -name theme.json | wc -l | tr -d ' ') themes, $(find "$ROOT/resources/widgets" -name widget.json | wc -l | tr -d ' ') widgets, the menu bar and default shortcuts"

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
