#!/bin/bash
# Copies the repository's resources into the layout of the app's
# Contents/Resources, which is what Paths.resources expects. The repository
# keeps one folder per tool; the bundle keeps the folders earlier versions
# read, so installed agents and startup files keep finding them.
# Usage: tools/stage-resources.sh <destination>
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${1:?Usage: tools/stage-resources.sh <destination>}"
SOURCE="$ROOT/resources"

mkdir -p "$DEST/sketchybar" "$DEST/launchers" "$DEST/plugins"
cp "$SOURCE/app/logo.svg" "$DEST/"
cp -R "$SOURCE/themes" "$SOURCE/widgets" "$SOURCE/skhd" "$DEST/"
cp "$SOURCE/sketchybar/sketchybar-app-font.ttf" "$DEST/sketchybar/"
cp "$SOURCE/yabai/macarchy-yabairc" "$SOURCE/sketchybar/macarchy-sketchybarrc" "$DEST/launchers/"
cp -R "$SOURCE/neovim" "$DEST/plugins/neovim"
