#!/bin/bash
if [ "$SELECTED" = "true" ]; then
  sketchybar --set "$NAME" \
    icon.highlight=on \
    label.highlight=on \
    icon.color=0xffffffff \
    label.color=0xffffffff \
    background.drawing=off
else
  sketchybar --set "$NAME" \
    icon.highlight=off \
    label.highlight=off \
    icon.color=0xffcfcfcf \
    label.color=0xffcfcfcf \
    background.drawing=off
fi
