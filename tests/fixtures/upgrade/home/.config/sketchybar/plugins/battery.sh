#!/usr/bin/env bash

# shellcheck source=/dev/null
source "${CONFIG_DIR:-$HOME/.config/sketchybar}/colors.sh"

BATTERY_INFO="$(pmset -g batt)"
PERCENTAGE="$(printf '%s\n' "$BATTERY_INFO" | grep -Eo "[0-9]+%" | cut -d% -f1)"
POWER_SOURCE="$(printf '%s\n' "$BATTERY_INFO" | awk -F"'" '/Now drawing from/ {print $2; exit}')"
BATTERY_STATUS="$(printf '%s\n' "$BATTERY_INFO" | awk -F';' '/InternalBattery/ { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit }')"

case "$BATTERY_STATUS" in
  charging|charged) CHARGING="1" ;;
  *) CHARGING="" ;;
esac

EFFECTIVE_POWER_SOURCE="${POWER_SOURCE:-AC Power}"
if [ "$BATTERY_STATUS" = "discharging" ]; then
  EFFECTIVE_POWER_SOURCE="Battery Power"
fi

# Emit "<key> <value>" so we know which scheme is in use — the two keys
# assign different meanings to the same numeric value (see below).
MODE_RAW="$(
  pmset -g custom 2>/dev/null | awk -v target="$EFFECTIVE_POWER_SOURCE" '
    $0 == target ":" { in_section=1; next }
    in_section && /^[^[:space:]]/ { in_section=0 }
    in_section && ($1 == "lowpowermode" || $1 == "powermode") { print $1, $2; exit }
  '
)"

if [ "$MODE_RAW" = "" ]; then
  MODE_RAW="$(
    for plist in /Library/Preferences/com.apple.PowerManagement.*.plist; do
      [ -f "$plist" ] || continue
      defaults read "${plist%.plist}" "$EFFECTIVE_POWER_SOURCE" 2>/dev/null |
        awk '
          $1 == "LowPowerMode" {
            gsub(";", "", $3)
            print "lowpowermode", $3
            found = 1
            exit
          }
          END { if (!found) exit 1 }
        ' &&
        break
    done
  )"
fi

MODE_VAL="${MODE_RAW##* }"
case "$MODE_VAL" in ''|*[!0-9]*) MODE_VAL=0 ;; esac

# Both pmset keys agree on the raw value (verified against the
# HighPowerMode/LowPowerMode booleans in the PowerManagement plist):
#   0 = automatic/normal, 1 = low power, 2 = high power
case "$MODE_VAL" in
  1) POWER_MODE=1 ;;  # low power
  2) POWER_MODE=2 ;;  # high power
  *) POWER_MODE=0 ;;  # normal / automatic
esac

if [ "$PERCENTAGE" = "" ]; then
  exit 0
fi

case ${PERCENTAGE} in
  9[0-9]|100) ICON="􀛨"
  ;;
  [6-8][0-9]) ICON="􀺸"
  ;;
  [3-5][0-9]) ICON="􀺶"
  ;;
  [1-2][0-9]) ICON="􀛩"
  ;;
  *) ICON="􀛪"
esac

if [ -n "$CHARGING" ]; then
  ICON="􀢋"
fi

ICON_COLOR="${WHITE:-0xffffffff}"

if [ "$PERCENTAGE" -lt 7 ]; then
  ICON_COLOR="${DANGER_COLOR:-0xffff453a}"
elif [ "$POWER_MODE" = "1" ]; then
  ICON_COLOR="${WARNING_COLOR:-0xffFFD60A}"
fi

sketchybar --set "$NAME" icon="$ICON" icon.color="$ICON_COLOR" label="${PERCENTAGE}%"
