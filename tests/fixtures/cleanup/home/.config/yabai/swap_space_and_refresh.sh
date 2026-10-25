#!/usr/bin/env bash
set -euo pipefail

# yabai validates the target itself (a non-existent or already-focused Space
# exits non-zero), so the read-back query, jq and the python wrapper this used to
# shell out to are all redundant — that was ~8 processes per keypress for work
# yabai already does.
target_space="${1:-}"

case "$target_space" in
  [1-9]|10) ;;
  *) exit 64 ;;
esac

YABAI_BIN="${YABAI_BIN:-/opt/homebrew/bin/yabai}"
SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-/opt/homebrew/bin/sketchybar}"
LOCK_DIR="${TMPDIR:-/tmp}/yabai-space-swap.lock"

# Drop overlapping key repeats instead of queueing swaps that land after the
# keys are released. mkdir is the atomic test-and-set; macOS has no flock(1).
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  if [ -n "$(find "$LOCK_DIR" -maxdepth 0 -mmin +1 2>/dev/null)" ]; then
    rmdir "$LOCK_DIR" 2>/dev/null || true
    mkdir "$LOCK_DIR" 2>/dev/null || exit 0
  else
    exit 0
  fi
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT INT TERM

"$YABAI_BIN" -m space --swap "$target_space" 2>/dev/null || exit 0

# Indices moved, so both the highlight and the window icons need a re-render.
"$SKETCHYBAR_BIN" --trigger space_windows_change >/dev/null 2>&1 || true
