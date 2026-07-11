#!/usr/bin/env bash

sketchybar --add item battery right
sketchybar --set battery \
  background.border_width=0 \
  padding_left=0 \
  padding_right=0 \
  update_freq=5 \
  script="$PLUGIN_DIR/battery.sh"
sketchybar --subscribe battery system_woke power_source_change
