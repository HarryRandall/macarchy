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
echo "==> OK"
