#!/bin/bash

SPACE_SIDS=(1 2 3 4 5 6)

for sid in "${SPACE_SIDS[@]}"
do
  sketchybar --add space space.$sid left                                 \
             --set space.$sid space=$sid                                 \
                              icon=$sid                                  \
                              icon.font="SF Pro:Semibold:12.0"          \
                              icon.color=$TEXT_COLOR                     \
                              padding_left=2                             \
                              label=""                                   \
                              label.font="sketchybar-app-font:Regular:13.0" \
                              label.color=$TEXT_COLOR                    \
                              label.padding_right=20                     \
                              label.y_offset=-1                          \
                              background.drawing=off                     \
                              background.color=0x00000000                \
                              script="$PLUGIN_DIR/space.sh"
done

sketchybar --add item space_labels_updater left                          \
           --set space_labels_updater drawing=off                        \
                                     width=0                             \
                                     label.drawing=off                   \
                                     icon.drawing=off                    \
                                     updates=on                          \
                                     script="$PLUGIN_DIR/space_windows.sh" \
           --subscribe space_labels_updater space_windows_change yabai_space_labels_refresh system_woke
