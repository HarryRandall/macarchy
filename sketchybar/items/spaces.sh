#!/bin/bash

"$PLUGIN_DIR/space_windows.sh" --reconcile

sketchybar --add item space_labels_updater left                          \
           --set space_labels_updater drawing=off                        \
                                     width=0                             \
                                     label.drawing=off                   \
                                     icon.drawing=off                    \
                                     updates=on                          \
                                     script="$PLUGIN_DIR/space_windows.sh" \
           --subscribe space_labels_updater space_windows_change yabai_space_labels_refresh system_woke
