#!/bin/bash
# Macarchy's menu bar. Run by `macarchy startup sketchybar` at login; geometry,
# visibility and component edits from the Menu Bar page are applied after it.
set -uo pipefail

BAR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$BAR_DIR/lib.sh"
SKETCHYBAR="$(macarchy_find sketchybar)"
export BAR_DIR SKETCHYBAR
PLUGIN_DIR="$BAR_DIR/plugins"
export PLUGIN_DIR

"$SKETCHYBAR" --remove '/.*/' >/dev/null 2>&1 || true

# BAR_COLOR comes from the theme and defaults to one step above transparent:
# a fully transparent bar is treated as pass-through by the compositor, which
# leaves stale pixels where items relayout. Bar, font and defaults go out as
# one call, since every call is a repaint.
"$SKETCHYBAR" --bar height=35 \
                    blur_radius=0 \
                    display=all \
                    position=top \
                    sticky=on \
                    padding_left=10 \
                    padding_right=10 \
                    color="$BAR_COLOR" \
              --load-font "$BAR_DIR/sketchybar-app-font.ttf" \
              --default icon.font="SF Pro:Semibold:15.0" \
                        icon.color="$TEXT_COLOR" \
                        label.font="SF Pro:Semibold:12.0" \
                        label.color="$TEXT_COLOR" \
                        background.color=0x00000000 \
                        background.border_color=0x33ffffff \
                        background.border_width=1 \
                        background.drawing=on \
                        background.corner_radius=5 \
                        background.height=24 \
                        padding_left=5 \
                        padding_right=5 \
                        label.y_offset=1 \
                        label.padding_left=4 \
                        label.padding_right=10 \
                        icon.padding_left=10 \
                        icon.padding_right=4

for item in spaces calendar battery system; do
  # shellcheck source=/dev/null
  source "$BAR_DIR/items/$item.sh"
done
