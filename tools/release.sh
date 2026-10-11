#!/bin/bash
# Builds a release zip and its SHA-256 for a GitHub release.
# Usage: ./tools/release.sh 0.1.0
set -euo pipefail
VERSION="${1:?Usage: ./tools/release.sh <version>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLIST="$ROOT/macarchy/app/resources/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(git -C "$ROOT" rev-list --count HEAD)" "$PLIST"
"$ROOT/tools/build.sh" release
cd "$ROOT/.build/artifacts"
rm -f Macarchy.zip
ditto -c -k --keepParent Macarchy.app Macarchy.zip
shasum -a 256 Macarchy.zip | tee Macarchy.zip.sha256
echo "Upload Macarchy.zip and paste the SHA-256 into the release notes."
