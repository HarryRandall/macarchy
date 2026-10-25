#!/bin/bash

sketchybar --add item battery right \
           --set battery background.border_width=0 \
                         padding_left=0                \
                         padding_right=0               \
                         update_freq=5                \
                         script="$PLUGIN_DIR/battery.sh" \
           --subscribe battery system_woke power_source_change
