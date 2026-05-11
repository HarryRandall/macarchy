#!/bin/bash

sketchybar --add item ram right \
           --set ram background.border_width=0 \
                     padding_left=0 \
                     padding_right=0 \
                     update_freq=10 \
                     icon=􀫦        \
                     script="$PLUGIN_DIR/ram.sh"
