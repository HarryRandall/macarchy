#!/bin/bash
source "$(dirname "$0")/../lib.sh"
SKETCHYBAR="$(macarchy_find sketchybar)"

info="$(pmset -g batt)"
percentage="$(printf '%s\n' "$info" | grep -Eo '[0-9]+%' | head -1 | tr -d %)"
if [ -z "$percentage" ]; then
  "$SKETCHYBAR" --set "$NAME" drawing=off
  exit 0
fi

case "$percentage" in
  9[0-9] | 100) icon=􀛨 ;;
  [6-8][0-9]) icon=􀺸 ;;
  [3-5][0-9]) icon=􀺶 ;;
  [1-2][0-9]) icon=􀛩 ;;
  *) icon=􀛪 ;;
esac
printf '%s\n' "$info" | grep -q 'AC Power' && icon=􀢋

colour="$TEXT_COLOR"
[ "$percentage" -lt 10 ] && colour="$DANGER_COLOR"
"$SKETCHYBAR" --set "$NAME" drawing=on icon="$icon" icon.color="$colour" label="$percentage%"
