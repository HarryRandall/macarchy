#!/usr/bin/env bash

set -u

CONFIG_ROOT="${CONFIG_DIR:-$HOME/.config/sketchybar}"
STATE_DIR="${SKETCHYBAR_STATE_DIR:-$CONFIG_ROOT/.state}"
DATA_FILE="${MACMON_DATA_FILE:-$STATE_DIR/macmon.json}"
PID_FILE="$STATE_DIR/macmon-stream.pid"
LOCK_DIR="$STATE_DIR/macmon-stream.lock"
MACMON_BIN="$(command -v "${MACMON_BIN:-macmon}" 2>/dev/null || true)"
INTERVAL="${MACMON_INTERVAL:-1000}"

stream_is_running() {
  local pid=""

  [ -r "$PID_FILE" ] && read -r pid < "$PID_FILE"
  case "$pid" in
    ''|*[!0-9]*) return 1 ;;
  esac
  kill -0 "$pid" 2>/dev/null || return 1
  ps -p "$pid" -o command= 2>/dev/null | grep -F 'macmon_stream.sh --run' >/dev/null
}

start_stream() {
  local attempt

  [ -n "$MACMON_BIN" ] || exit 0
  mkdir -p "$STATE_DIR"

  stream_is_running && exit 0
  rm -f "$PID_FILE"
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    # Another reload may have acquired the lock just before its runner wrote
    # the PID file. Give it a moment before treating the lock as stale.
    for attempt in 1 2 3 4 5; do
      sleep 0.05
      stream_is_running && exit 0
    done
    rmdir "$LOCK_DIR" 2>/dev/null || exit 0
    mkdir "$LOCK_DIR" 2>/dev/null || exit 0
  fi

  nohup /bin/bash "$0" --run >/dev/null 2>&1 &
}

run_stream() {
  local fifo="$STATE_DIR/macmon-stream.$$.fifo"
  local temporary="$DATA_FILE.$$"
  local macmon_pid=""
  local line=""

  [ -n "$MACMON_BIN" ] || exit 0
  mkdir -p "$STATE_DIR"
  printf '%s\n' "$$" > "$PID_FILE.$$.tmp"
  mv "$PID_FILE.$$.tmp" "$PID_FILE"
  rm -f "$fifo"
  mkfifo "$fifo" || exit 1

  cleanup() {
    [ -n "$macmon_pid" ] && kill "$macmon_pid" 2>/dev/null || true
    rm -f "$fifo" "$temporary"
    if [ "$(cat "$PID_FILE" 2>/dev/null)" = "$$" ]; then
      rm -f "$PID_FILE"
      rmdir "$LOCK_DIR" 2>/dev/null || true
    fi
  }
  trap cleanup EXIT INT TERM

  "$MACMON_BIN" pipe --samples 0 --interval "$INTERVAL" > "$fifo" 2>/dev/null &
  macmon_pid=$!

  while IFS= read -r line; do
    case "$line" in
      \{*\})
        printf '%s\n' "$line" > "$temporary"
        mv "$temporary" "$DATA_FILE"
        ;;
    esac

    # The sampler belongs to SketchyBar and should not outlive it.
    pgrep -x sketchybar >/dev/null 2>&1 || break
  done < "$fifo"
}

case "${1:-}" in
  --start) start_stream ;;
  --run) run_stream ;;
  *) printf 'usage: %s --start\n' "$0" >&2; exit 1 ;;
esac
