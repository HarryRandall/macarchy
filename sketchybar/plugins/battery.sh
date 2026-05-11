#!/bin/bash
PERCENTAGE="$(pmset -g batt | grep -Eo '[0-9]+%' | head -1)"
sketchybar --set $NAME label="$PERCENTAGE"
