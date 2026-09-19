#!/bin/bash
# Standalone checks for logic that can't be exercised through the GUI.
#
# The snapshot round-trip is here because snapshots are the safety net the
# whole migration is gated on, and the first version of it had two bugs that
# only showed up under test: second-resolution ids collided, so rapid writes
# clobbered each other and restore destroyed the snapshot it was reading from.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/Sources/MacarchySettings"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

echo "==> Snapshot round-trip"
swiftc -O "$SRC/Model/SnapshotStore.swift" "$SRC/Daemon/Daemon.swift" \
       "$ROOT/Tests/SnapshotRoundTrip/main.swift" -o "$OUT/snaptest"
"$OUT/snaptest" | tee "$OUT/result.txt"

if grep -qE '\(expected [^)]*\)$' "$OUT/result.txt"; then
  grep -E '\(expected' "$OUT/result.txt" | while read -r line; do
    got="${line%% (expected*}"; want="${line##*(expected }"; want="${want%)}"
    case "$got" in *"$want"*) ;; *) echo "FAIL: $line"; exit 1 ;; esac
  done
fi
echo "==> Generated file behaviour"
swiftc -O "$SRC/Model/GeneratedFile.swift" "$SRC/Model/SnapshotStore.swift" \
       "$SRC/Daemon/Daemon.swift" \
       "$ROOT/Tests/GeneratedFileBehaviour/main.swift" -o "$OUT/genfile"
"$OUT/genfile" | tee -a "$OUT/result.txt"

echo "==> Manifest / env round-trip"
swiftc -O "$SRC/Model/ThemeManifest.swift" \
       "$ROOT/Tests/ManifestRoundTrip/main.swift" -o "$OUT/manifest"
"$OUT/manifest" | tee -a "$OUT/result.txt"

grep -E '\(expected' "$OUT/result.txt" | while read -r line; do
  got="${line%% (expected*}"; want="${line##*(expected }"; want="${want%)}"
  case "$got" in *"$want"*) ;; *) echo "FAIL: $line"; exit 1 ;; esac
done

echo "==> Ghostty port: Swift vs the shell it replaced"
swiftc -O "$ROOT/Sources/MacarchyKit/GhosttyApplier.swift" \
       "$ROOT/Tests/GhosttyPort/main.swift" -o "$OUT/ghosttyport"

CASES="$OUT/cases"; mkdir -p "$CASES"
printf 'font-size = 13\n\n\n\nwindow-padding-x = 8\n\n\n'                > "$CASES/trailing-blanks"
printf 'background = #111111\nfont-size = 13\npalette = 0=#000000\ntheme = foo\n' > "$CASES/colour-lines"
printf '  background   =   #111111\n\tforeground=#fff\nfont-size = 13\n'      > "$CASES/whitespace-variants"
printf 'config-file = ~/.themes/x.conf\nconfig-file = ~/other/y.conf\nfont-size=13\n' > "$CASES/config-file-refs"
printf 'font-size = 13\n# --- THEME COLORS (old) ---\nbackground = #999999\n'  > "$CASES/existing-marker"
printf ''                                                                       > "$CASES/empty"
printf 'a = 1\n\nb = 2\n\n\nc = 3\n'                                        > "$CASES/interior-blanks"
printf 'backgroundish = 1\nforegrounds = 2\nbackground-opacity = 0.9\n'        > "$CASES/near-miss-keys"

THEMES="$HOME/.config/macarchy-settings/themes"
ghostty_fail=0; ghostty_checks=0

# Every theme against the live config, then every edge case against one theme.
for theme in "$THEMES"/*/; do
  [ -f "$theme/ghostty.conf" ] || continue
  name=$(basename "$theme")
  "$ROOT/Tests/GhosttyPort/reference.sh" "$HOME/.config/ghostty/config" "$theme/ghostty.conf" "$name" > "$OUT/a" 2>/dev/null
  "$OUT/ghosttyport" "$HOME/.config/ghostty/config" "$theme/ghostty.conf" "$name" > "$OUT/b" 2>/dev/null
  ghostty_checks=$((ghostty_checks+1))
  diff -q "$OUT/a" "$OUT/b" >/dev/null || { echo "  DIFFERS: theme $name"; ghostty_fail=1; }
done

for case_file in "$CASES"/*; do
  "$ROOT/Tests/GhosttyPort/reference.sh" "$case_file" "$THEMES/midnight/ghostty.conf" midnight > "$OUT/a" 2>/dev/null
  "$OUT/ghosttyport" "$case_file" "$THEMES/midnight/ghostty.conf" midnight > "$OUT/b" 2>/dev/null
  ghostty_checks=$((ghostty_checks+1))
  diff -q "$OUT/a" "$OUT/b" >/dev/null || { echo "  DIFFERS: case $(basename "$case_file")"; ghostty_fail=1; }
done

echo "ghostty comparisons: $ghostty_checks"
echo "ghostty mismatches: $ghostty_fail (expected 0)"
[ "$ghostty_fail" -eq 0 ] || exit 1

echo "==> OK"
