#!/bin/bash
source "$(dirname "$0")/../lib.sh"
# Memory pressure, the figure Activity Monitor colours its graph by.
free="$(memory_pressure 2>/dev/null | awk -F': ' '/free percentage/ { gsub("%", "", $2); print $2 }')"
"$(macarchy_find sketchybar)" --set "$NAME" label="$((100 - ${free:-100}))%"
