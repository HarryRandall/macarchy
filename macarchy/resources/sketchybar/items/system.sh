#!/bin/bash
# Right-side items render in reverse add order: memory then CPU, left to right.
"$SKETCHYBAR" --add item cpu right \
              --set cpu icon=􀧓 background.border_width=0 update_freq=5 \
                    script="$PLUGIN_DIR/cpu.sh" \
              --add item memory right \
              --set memory icon=􀫦 background.border_width=0 update_freq=15 \
                    script="$PLUGIN_DIR/memory.sh"
