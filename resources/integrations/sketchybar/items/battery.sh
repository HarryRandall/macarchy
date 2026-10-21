#!/bin/bash
# Desktops have no battery; the plugin hides the item when pmset reports none.
"$SKETCHYBAR" --add item battery right \
              --set battery background.border_width=0 padding_left=0 padding_right=0 \
                    update_freq=60 script="$PLUGIN_DIR/battery.sh" \
              --subscribe battery system_woke power_source_change
