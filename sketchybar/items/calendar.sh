#!/bin/bash

sketchybar --add item calendar right \
           --set calendar icon=􀧞     \
                          padding_left=0 \
                          background.border_width=0 \
                          update_freq=30 \
                          script="$PLUGIN_DIR/calendar.sh"
