#!/bin/bash

sketchybar --add item media left \
           --set media label.color=$ACCENT_COLOR \
                       update_freq=5             \
                       label.max_chars=20         \
                       icon.padding_left=0        \
                       scroll_texts=on            \
                       icon=􀑪                     \
                       icon.color=$ACCENT_COLOR   \
                       background.drawing=off     \
                       script="$PLUGIN_DIR/media.sh" \
           --subscribe media media_change system_woke
