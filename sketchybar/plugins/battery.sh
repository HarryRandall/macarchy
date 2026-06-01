#!/bin/sh

# shellcheck source=/dev/null
source "${CONFIG_DIR:-$HOME/.config/sketchybar}/colors.sh"

BATTERY_INFO="$(pmset -g batt)"
PERCENTAGE="$(printf '%s\n' "$BATTERY_INFO" | grep -Eo "\d+%" | cut -d% -f1)"
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

LOW_POWER_MODE="$(
  pmset -g custom 2>/dev/null | awk -v target="$EFFECTIVE_POWER_SOURCE" '
    $0 == target ":" { in_section=1; next }
    in_section && /^[^[:space:]]/ { in_section=0 }
    in_section && $1 == "lowpowermode" { print $2; exit }
  '
)"

if [ "$LOW_POWER_MODE" = "" ]; then
  LOW_POWER_MODE="$(
    for plist in /Library/Preferences/com.apple.PowerManagement.*.plist; do
      [ -f "$plist" ] || continue
      defaults read "${plist%.plist}" "$EFFECTIVE_POWER_SOURCE" 2>/dev/null |
        awk '$1 == "LowPowerMode" { gsub(";", "", $3); print $3; exit }' &&
        break
    done
  )"
fi

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

if [ "${LOW_POWER_MODE:-0}" = "1" ]; then
  ICON_COLOR="${WARNING_COLOR:-0xffFFD60A}"
elif [ "$PERCENTAGE" -lt 7 ]; then
  ICON_COLOR="${DANGER_COLOR:-0xffff453a}"
fi

sketchybar --set "$NAME" icon="$ICON" icon.color="$ICON_COLOR" label="${PERCENTAGE}%"
