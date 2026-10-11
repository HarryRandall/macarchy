#!/bin/bash
# Rebuilds macarchy/app/resources/AppIcon.icns from macarchy/resources/logo.svg.
# Small sizes get thicker strokes so the outline survives at 16 px.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
swiftc -O "$ROOT/tools/icon.swift" -o "$WORK/icon"
SET="$WORK/AppIcon.iconset"
mkdir -p "$SET"
stroke() { if [ "$1" -le 64 ]; then echo 24; elif [ "$1" -le 128 ]; then echo 20; else echo 16; fi; }
for size in 16 32 128 256 512; do
  "$WORK/icon" "$ROOT/macarchy/resources/logo.svg" "$SET/icon_${size}x${size}.png" "$size" "$(stroke "$size")"
  double=$((size * 2))
  "$WORK/icon" "$ROOT/macarchy/resources/logo.svg" "$SET/icon_${size}x${size}@2x.png" "$double" "$(stroke "$double")"
done
iconutil -c icns "$SET" -o "$ROOT/macarchy/app/resources/AppIcon.icns"
echo "Wrote macarchy/app/resources/AppIcon.icns"
