#!/bin/bash
USED=$(df -h / | tail -1 | awk '{print $5}')
sketchybar --set $NAME label="DSK:$USED"
