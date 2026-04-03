#!/bin/bash

STATE_DIR="${TMPDIR%/}/sketchybar-hover"
PID_FILE="$STATE_DIR/restore.pid"

mkdir -p "$STATE_DIR"

start_restore_helper() {
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    return
  fi

  nohup "$CONFIG_DIR/plugins/hover_restore.sh" >/dev/null 2>&1 &
  echo $! > "$PID_FILE"
}

case "$SENDER" in
  mouse.entered.global)
    sketchybar --animate tanh 2 --bar y_offset=-40
    start_restore_helper
    ;;
  mouse.exited.global)
    start_restore_helper
    ;;
esac
