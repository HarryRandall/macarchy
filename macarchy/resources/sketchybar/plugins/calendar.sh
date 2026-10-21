#!/bin/bash
source "$(dirname "$0")/../lib.sh"
"$(macarchy_find sketchybar)" --set "$NAME" label="$(date +'%a %d %b %H:%M')"
