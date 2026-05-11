#!/bin/bash

STATE_DIR="${TMPDIR%/}/sketchybar-hover"
PID_FILE="$STATE_DIR/restore.pid"
TOP_ZONE=34

mkdir -p "$STATE_DIR"

cleanup() {
  rm -f "$PID_FILE"
}

trap cleanup EXIT

while true; do
  distance_from_top="$(swift -e '
import AppKit

let point = NSEvent.mouseLocation
let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }) ?? NSScreen.main
let distance = Int((screen?.frame.maxY ?? point.y) - point.y)
print(distance)
' 2>/dev/null)"

  if [ -z "$distance_from_top" ]; then
    sleep 0.03
    continue
  fi

  if [ "$distance_from_top" -gt "$TOP_ZONE" ]; then
    sketchybar --animate tanh 2 --bar y_offset=0
    exit 0
  fi

  sleep 0.03
done
