#!/usr/bin/env bash

FREE_PERCENT="$(memory_pressure 2>/dev/null | awk -F': ' '/System-wide memory free percentage/ { gsub("%", "", $2); print $2; exit }')"
[ -n "$FREE_PERCENT" ] || FREE_PERCENT=0
USED_PERCENT=$((100 - FREE_PERCENT))

sketchybar --set "$NAME" label="${USED_PERCENT}%"
