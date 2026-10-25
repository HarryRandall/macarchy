#!/bin/bash

"$PLUGIN_DIR/space_windows.sh" --reconcile

# One hidden item renders every space item in bulk. The space.* items carry no
# script of their own, so a space change costs one render instead of one process
# chain per item.
sketchybar --add event macarchy_spaces_changed                             \
           --add item space_labels_updater left                            \
           --set space_labels_updater drawing=off                          \
                                     width=0                               \
                                     label.drawing=off                     \
                                     icon.drawing=off                      \
                                     updates=on                            \
                                     script="$PLUGIN_DIR/space_windows.sh" \
           --subscribe space_labels_updater space_change                   \
                                            space_windows_change           \
                                            system_woke macarchy_spaces_changed
