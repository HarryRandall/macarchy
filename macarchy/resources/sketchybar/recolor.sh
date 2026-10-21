#!/bin/bash
# Repaints the running bar in the active theme's colours without rebuilding
# it, which would tear every item down and visibly paint the bar back in.
set -uo pipefail

BAR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$BAR_DIR/lib.sh"
SKETCHYBAR="$(macarchy_find sketchybar)"

"$SKETCHYBAR" --query bar >/dev/null 2>&1 || exit 0

# Space items pick accent or text per Space, so their renderer owns them.
"$BAR_DIR/plugins/spaces.sh" --recolor

# --default only affects items added later, so existing ones are set too.
args=(--bar color="$BAR_COLOR" --default icon.color="$TEXT_COLOR" label.color="$TEXT_COLOR")
for item in calendar battery cpu memory; do
  "$SKETCHYBAR" --query "$item" >/dev/null 2>&1 &&
    args+=(--set "$item" icon.color="$TEXT_COLOR" label.color="$TEXT_COLOR")
done
"$SKETCHYBAR" "${args[@]}" >/dev/null 2>&1
