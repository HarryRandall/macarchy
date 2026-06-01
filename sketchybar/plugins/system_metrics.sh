#!/bin/bash

CONFIG_ROOT="${CONFIG_DIR:-$HOME/.config/sketchybar}"
STATE_DIR="$CONFIG_ROOT/.state"
MACMON_URL="${MACMON_URL:-http://localhost:9090/json}"

mkdir -p "$STATE_DIR"

read_macmon() {
  curl --max-time 1 -fsS "$MACMON_URL" 2>/dev/null
}

format_macmon_rows() {
  /usr/bin/python3 -c '
import json
import os
import re
import sys

try:
    d = json.load(sys.stdin)
except Exception:
    d = {}

def num(path):
    cur = d
    try:
        for part in path:
            cur = cur[part]
        return float(cur)
    except Exception:
        return None

def _fmt(n, suffix, fixed=False):
    if n >= 100:
        n = 99.9
    return f"{n:4.1f}{suffix}" if fixed else f"{n:.1f}{suffix}"

def pct(value):
    return "--.-%" if value is None else _fmt(value * 100, "%")

def temp(value):
    return "--.-°" if value is None else _fmt(value, "°", True)

def gib(value):
    return "--.-G" if value is None else _fmt(value / 1073741824, "G", True)

def pressure_memory():
    output = os.environ.get("MEMORY_PRESSURE_OUTPUT", "")
    total_match = re.search(r"The system has (\d+)", output)
    free_match = re.search(r"System-wide memory free percentage:\s*(\d+)%", output)
    if not total_match or not free_match:
        return None, None

    total = float(total_match.group(1))
    pressure_pct = max(0.0, min(100.0, 100.0 - float(free_match.group(1))))
    return pressure_pct / 100.0, total * pressure_pct / 100.0

ram_total = num(("memory", "ram_total"))
ram_pct, ram_used = pressure_memory()
if ram_pct is None:
    ram_used = num(("memory", "ram_usage"))
    ram_pct = None if ram_total is None or ram_used is None or ram_total == 0 else ram_used / ram_total

rows = {
    "cpu_top": pct(num(("cpu_usage_pct",))),
    "cpu_bottom": temp(num(("temp", "cpu_temp_avg"))),
    "gpu_top": pct(num(("gpu_usage", 1))),
    "gpu_bottom": temp(num(("temp", "gpu_temp_avg"))),
    "ram_top": pct(ram_pct),
    "ram_bottom": gib(ram_used),
}

for key, value in rows.items():
    print(f"{key}={value}")
'
}

DATA="$(read_macmon)"
MEMORY_PRESSURE_OUTPUT="$(memory_pressure 2>/dev/null)"
METRICS="$(printf '%s' "$DATA" | MEMORY_PRESSURE_OUTPUT="$MEMORY_PRESSURE_OUTPUT" format_macmon_rows)"

get_row() {
  local key="$1"
  printf '%s\n' "$METRICS" | awk -F= -v key="$key" '$1 == key { print substr($0, length(key) + 2); exit }'
}

ARGS=()

if [ -n "$DATA" ]; then
  ARGS+=(
    --set cpu.text icon="$(get_row cpu_top)" label="$(get_row cpu_bottom)"
    --set gpu.text icon="$(get_row gpu_top)" label="$(get_row gpu_bottom)"
  )
fi

ARGS+=(--set ram.text icon="$(get_row ram_top)" label="$(get_row ram_bottom)")

if [ "${#ARGS[@]}" -gt 0 ]; then
  sketchybar "${ARGS[@]}"
fi
