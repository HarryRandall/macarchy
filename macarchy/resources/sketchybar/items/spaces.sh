#!/bin/bash
"$PLUGIN_DIR/spaces.sh" --reconcile

# One hidden item renders every Space item in bulk, so a Space change costs one
# render instead of one process per item.
"$SKETCHYBAR" --add item space_labels_updater left \
              --set space_labels_updater drawing=off width=0 label.drawing=off \
                    icon.drawing=off updates=on script="$PLUGIN_DIR/spaces.sh" \
              --subscribe space_labels_updater space_change space_windows_change system_woke
