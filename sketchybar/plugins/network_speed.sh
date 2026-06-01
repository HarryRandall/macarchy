#!/bin/bash

CONFIG_ROOT="${CONFIG_DIR:-$HOME/.config/sketchybar}"
STATE_DIR="$CONFIG_ROOT/.state"
STATE_FILE="$STATE_DIR/network_speed"

mkdir -p "$STATE_DIR"

active_interface() {
  local iface

  iface="$(route get default 2>/dev/null | awk '/interface:/ { print $2; exit }')"
  if [ -n "$iface" ]; then
    printf '%s\n' "$iface"
    return 0
  fi

  iface="$(ifconfig 2>/dev/null | awk '
    /^[a-zA-Z0-9]+:/ {
      sub(":", "", $1)
      current = $1
      active = 0
    }
    /status: active/ {
      active = 1
    }
    /inet / && current != "lo0" && active == 1 {
      print current
      exit
    }
  ')"

  printf '%s\n' "${iface:-en0}"
}

read_counters() {
  local iface="$1"

  netstat -ibn -I "$iface" 2>/dev/null | awk -v iface="$iface" '
    $1 == iface && $7 ~ /^[0-9]+$/ && $10 ~ /^[0-9]+$/ {
      rx += $7
      tx += $10
    }
    END {
      if (rx == "") rx = 0
      if (tx == "") tx = 0
      print rx, tx
    }
  '
}

format_speed() {
  /usr/bin/python3 -c '
import sys

speed = float(sys.argv[1]) / 1048576
if speed >= 100:
    speed = 99.9
print(f"{speed:.1f}MB/s")
' "${1:-0}"
}

now="$(date +%s)"
iface="$(active_interface)"
read -r rx tx <<< "$(read_counters "$iface")"

prev_time=""
prev_iface=""
prev_rx=""
prev_tx=""

if [ -f "$STATE_FILE" ]; then
  read -r prev_time prev_iface prev_rx prev_tx < "$STATE_FILE"
fi

down_bps=0
up_bps=0

if [ "$iface" = "$prev_iface" ] && [ -n "$prev_time" ] && [ "$now" -gt "$prev_time" ]; then
  elapsed=$((now - prev_time))
  if [ "$rx" -ge "${prev_rx:-0}" ] && [ "$tx" -ge "${prev_tx:-0}" ]; then
    down_bps=$(((rx - prev_rx) / elapsed))
    up_bps=$(((tx - prev_tx) / elapsed))
  fi
fi

printf '%s %s %s %s\n' "$now" "$iface" "$rx" "$tx" > "$STATE_FILE"

sketchybar --set network.text \
  icon="$(format_speed "$up_bps")" \
  label="$(format_speed "$down_bps")"
