#!/usr/bin/env bash

CONFIG_ROOT="${CONFIG_DIR:-$HOME/.config/sketchybar}"
MACMON_DATA_FILE="${MACMON_DATA_FILE:-$CONFIG_ROOT/.state/macmon.json}"
MACMON_URL="${MACMON_URL:-}"
SKETCHYBAR_BIN="$(command -v "${SKETCHYBAR_BIN:-sketchybar}" 2>/dev/null || true)"
JQ_BIN="$(command -v "${JQ_BIN:-jq}" 2>/dev/null || true)"
CURL_BIN="$(command -v "${CURL_BIN:-curl}" 2>/dev/null || true)"
[ -n "$SKETCHYBAR_BIN" ] || exit 0

read_macmon() {
  if [ -n "$MACMON_URL" ]; then
    [ -n "$CURL_BIN" ] || return 1
    "$CURL_BIN" --max-time 1 -fsS "$MACMON_URL" 2>/dev/null
  elif [ -r "$MACMON_DATA_FILE" ]; then
    cat "$MACMON_DATA_FILE"
  else
    return 1
  fi
}

format_scaled() {
  local value="$1" scale="$2" suffix="$3" placeholder="$4" fixed_width="${5:-false}"

  awk -v value="$value" -v scale="$scale" -v suffix="$suffix" \
      -v placeholder="$placeholder" -v fixed_width="$fixed_width" 'BEGIN {
    if (value !~ /^-?[0-9]+([.][0-9]+)?$/) {
      print placeholder
      exit
    }

    number = value * scale
    if (number >= 99.95) printf "%.0f%s", number, suffix
    else if (fixed_width == "true") printf "%4.1f%s", number, suffix
    else printf "%.1f%s", number, suffix
  }'
}

format_ratio_percent() {
  local used="$1" total="$2"

  awk -v used="$used" -v total="$total" 'BEGIN {
    if (used !~ /^[0-9]+([.][0-9]+)?$/ || total !~ /^[0-9]+([.][0-9]+)?$/ || total <= 0) {
      print "--.-%"
      exit
    }

    percentage = used * 100 / total
    if (percentage >= 99.95) printf "%.0f%%", percentage
    else printf "%.1f%%", percentage
  }'
}

cpu_usage="NA"
cpu_temp="NA"
gpu_usage="NA"
gpu_temp="NA"
ram_used="NA"
ram_total="NA"

data="$(read_macmon || true)"
if [ -n "$data" ] && [ -n "$JQ_BIN" ]; then
  values="$(printf '%s' "$data" | "$JQ_BIN" -er '
    [
      ((try .cpu_usage_pct catch null) // "NA"),
      ((try .temp.cpu_temp_avg catch null) // "NA"),
      ((try .gpu_usage[1] catch null) // "NA"),
      ((try .temp.gpu_temp_avg catch null) // "NA"),
      ((try .memory.ram_usage catch null) // "NA"),
      ((try .memory.ram_total catch null) // "NA")
    ] | @tsv
  ' 2>/dev/null || true)"

  if [ -n "$values" ]; then
    IFS=$'\t' read -r cpu_usage cpu_temp gpu_usage gpu_temp ram_used ram_total <<< "$values"
  fi
fi

# ram_usage is macmon's actual used-byte counter. Memory pressure measures how
# comfortably macOS can satisfy allocations and is not a used-RAM percentage.
"$SKETCHYBAR_BIN" \
  --set cpu.text \
    icon="$(format_scaled "$cpu_usage" 100 % --.-%)" \
    label="$(format_scaled "$cpu_temp" 1 ° --.-° true)" \
  --set gpu.text \
    icon="$(format_scaled "$gpu_usage" 100 % --.-%)" \
    label="$(format_scaled "$gpu_temp" 1 ° --.-° true)" \
  --set ram.text \
    icon="$(format_ratio_percent "$ram_used" "$ram_total")" \
    label="$(format_scaled "$ram_used" 0.0000000009313225746154785 G --.-G true)"
