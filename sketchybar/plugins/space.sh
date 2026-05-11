#!/bin/sh

source "$CONFIG_DIR/colors.sh"

ACCENT_RGB="${ACCENT_COLOR#0x}"
ACCENT_RGB="${ACCENT_RGB#\#}"
if [ "${#ACCENT_RGB}" -eq 8 ]; then
  ACCENT_RGB="${ACCENT_RGB#??}"
fi
ACTIVE_BACKGROUND_COLOR="0x1a${ACCENT_RGB}"

if [ "$SELECTED" = true ]; then
  sketchybar --set "$NAME" background.drawing=on \
                         background.color=$ACTIVE_BACKGROUND_COLOR \
                         background.border_width=1 \
                         background.border_color=$ACCENT_COLOR \
                         label.color=$ACCENT_COLOR \
                         icon.color=$ACCENT_COLOR
else
  sketchybar --set "$NAME" background.drawing=off \
                         background.color=0x00000000 \
                         background.border_width=0 \
                         label.color=$TEXT_COLOR \
                         icon.color=$TEXT_COLOR
fi
