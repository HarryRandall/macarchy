#!/bin/bash

sketchybar --add item volume right \
           --set volume background.border_width=0 \
                     padding_left=0 \
                     padding_right=0 \
                     script="$PLUGIN_DIR/volume.sh" \
           --subscribe volume volume_change
