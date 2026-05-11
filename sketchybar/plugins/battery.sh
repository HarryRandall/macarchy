#!/bin/sh

# shellcheck source=/dev/null
source "${CONFIG_DIR:-$HOME/.config/sketchybar}/colors.sh"

BATTERY_INFO="$(pmset -g batt)"
PERCENTAGE="$(printf '%s\n' "$BATTERY_INFO" | grep -Eo "\d+%" | cut -d% -f1)"
POWER_SOURCE="$(printf '%s\n' "$BATTERY_INFO" | awk -F"'" '/Now drawing from/ {print $2; exit}')"
CHARGING="$(printf '%s\n' "$BATTERY_INFO" | grep 'AC Power')"
LOW_POWER_MODE="$(
  pmset -g custom 2>/dev/null | awk -v target="${POWER_SOURCE:-AC Power}" '
    $0 == target ":" { in_section=1; next }
    in_section && /^[^[:space:]]/ { in_section=0 }
    in_section && $1 == "lowpowermode" { print $2; exit }
  '
)"

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

if [ "$CHARGING" != "" ]; then
  ICON="􀢋"
fi

ICON_COLOR="${WHITE:-0xffffffff}"

if [ -n "$CHARGING" ]; then
  ICON_COLOR="${WHITE:-0xffffffff}"
elif [ "$PERCENTAGE" -lt 20 ]; then
  ICON_COLOR="${DANGER_COLOR:-0xffff453a}"
elif [ "${LOW_POWER_MODE:-0}" = "1" ]; then
  ICON_COLOR="${WARNING_COLOR:-0xffFFD60A}"
fi

sketchybar --set "$NAME" icon="$ICON" icon.color="$ICON_COLOR" label="${PERCENTAGE}%"
