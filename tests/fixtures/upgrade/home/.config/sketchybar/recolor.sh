#!/bin/bash
# Repaint the running bar in the current theme's colours without rebuilding it.
#
# A theme only ever changes ACCENT_COLOR and TEXT_COLOR, but the old path was
# `sketchybar --reload`, which re-runs the whole rc: every item torn down and
# re-added, macmon_stream restarted, and the bar visibly painting itself back in.
# This sets the colours on the items that are already there instead.
#
# Structural changes (a new item, different geometry) still need --reload; this
# only knows how to recolour what the rc built.

set -uo pipefail

CONFIG_ROOT="${CONFIG_DIR:-$HOME/.config/sketchybar}"
export CONFIG_DIR="$CONFIG_ROOT"
SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-/opt/homebrew/bin/sketchybar}"

[ -x "$SKETCHYBAR_BIN" ] || exit 0
"$SKETCHYBAR_BIN" --query bar >/dev/null 2>&1 || exit 0

# shellcheck source=/dev/null
source "$CONFIG_ROOT/colors.sh"

TEXT="${TEXT_COLOR:-0xffffffff}"

# The Space items pick between accent and text per Space, so the renderer owns
# them. Its diff keys on the colours, so a theme change re-sets all of them in
# one batch and a no-op theme change costs nothing.
"$CONFIG_ROOT/plugins/space_windows.sh" --recolor

# Everything else just wears TEXT_COLOR. --default only affects items added
# later, so each existing item is set explicitly — one invocation for the lot.
#
# battery.sh re-colours its own icon each tick (white/warning/danger), so only
# its label needs setting here; the icon is set anyway so the change is not held
# up by the 5s update.
"$SKETCHYBAR_BIN" \
  --default icon.color="$TEXT" label.color="$TEXT" \
  --set calendar     icon.color="$TEXT" label.color="$TEXT" \
  --set battery      icon.color="$TEXT" label.color="$TEXT" \
  --set cpu.text     icon.color="$TEXT" label.color="$TEXT" \
  --set gpu.text     icon.color="$TEXT" label.color="$TEXT" \
  --set ram.text     icon.color="$TEXT" label.color="$TEXT" \
  --set network.text icon.color="$TEXT" label.color="$TEXT" \
  >/dev/null 2>&1 || exit 1
