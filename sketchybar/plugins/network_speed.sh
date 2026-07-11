#!/bin/bash

CONFIG_ROOT="${CONFIG_DIR:-$HOME/.config/sketchybar}"
STATE_DIR="$CONFIG_ROOT/.state"
STATE_FILE="$STATE_DIR/network_speed"
SKETCHYBAR_BIN="$(command -v "${SKETCHYBAR_BIN:-sketchybar}" 2>/dev/null || true)"
[ -n "$SKETCHYBAR_BIN" ] || exit 0

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
      if (current != "" && current != "lo0" && active == 1 && has_inet == 1) {
        print current
        found = 1
        exit
      }
      sub(":", "", $1)
      current = $1
      active = 0
      has_inet = 0
    }
    /status: active/ {
      active = 1
    }
    /inet / {
      has_inet = 1
    }
    END {
      if (!found && current != "" && current != "lo0" && active == 1 && has_inet == 1) {
        print current
      }
    }
  ')"

  printf '%s\n' "${iface:-en0}"
}

read_counters() {
  local iface="$1"

  netstat -ibn -I "$iface" 2>/dev/null | awk -v iface="$iface" '
    $1 == iface && $7 ~ /^[0-9]+$/ && $10 ~ /^[0-9]+$/ {
      # macOS repeats the interface totals for each address family. Taking the
      # largest row avoids counting the same bytes two or three times.
      if (!found || $7 > rx) rx = $7
      if (!found || $10 > tx) tx = $10
      found = 1
    }
    END {
      if (!found) rx = tx = 0
      print rx, tx
    }
  '
}

format_speed() {
  awk -v bytes="${1:-0}" 'BEGIN {
    if (bytes !~ /^[0-9]+([.][0-9]+)?$/) bytes = 0
    speed = bytes / 1048576
    if (speed >= 1024) printf "%.1fGB/s", speed / 1024
    else if (speed >= 100) printf "%.0fMB/s", speed
    else printf "%.1fMB/s", speed
  }'
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

if [ "$iface" = "$prev_iface" ] \
  && [[ "$prev_time" =~ ^[0-9]+$ ]] \
  && [[ "$prev_rx" =~ ^[0-9]+$ ]] \
  && [[ "$prev_tx" =~ ^[0-9]+$ ]] \
  && [ "$now" -gt "$prev_time" ]; then
  elapsed=$((now - prev_time))
  if [ "$rx" -ge "${prev_rx:-0}" ] && [ "$tx" -ge "${prev_tx:-0}" ]; then
    down_bps=$(((rx - prev_rx) / elapsed))
    up_bps=$(((tx - prev_tx) / elapsed))
  fi
fi

tmp_file="$STATE_FILE.$$"
trap 'rm -f "$tmp_file"' EXIT
printf '%s %s %s %s\n' "$now" "$iface" "$rx" "$tx" > "$tmp_file"
mv "$tmp_file" "$STATE_FILE"
trap - EXIT

"$SKETCHYBAR_BIN" --set network.text \
  icon="$(format_speed "$up_bps")" \
  label="$(format_speed "$down_bps")"
