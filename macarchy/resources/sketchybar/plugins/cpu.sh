#!/bin/bash
source "$(dirname "$0")/../lib.sh"
# Total CPU across cores, as a share of the whole machine.
cores="$(sysctl -n hw.logicalcpu)"
usage="$(ps -A -o %cpu= | awk -v cores="$cores" '{ sum += $1 } END { printf "%.0f", sum / cores }')"
"$(macarchy_find sketchybar)" --set "$NAME" label="$usage%"
