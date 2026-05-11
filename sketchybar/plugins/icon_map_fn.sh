#!/bin/bash

CONFIG_ROOT="${CONFIG_DIR:-$HOME/.config/sketchybar}"

# shellcheck source=/dev/null
source "$CONFIG_ROOT/plugins/icon_map.sh"

__icon_map "${1:-Default}"
printf '%s\n' "${icon_result:-:default:}"
