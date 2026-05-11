#!/usr/bin/env bash

THEME_FILE="${CONFIG_DIR:-$HOME/.config/sketchybar}/theme.sh"
if [ -f "$THEME_FILE" ]; then
  # shellcheck source=/dev/null
  source "$THEME_FILE"
fi

PERCENTAGE="$(pmset -g batt | grep -Eo '[0-9]+%' | head -1 | tr -d '%' || true)"
CHARGING="$(pmset -g batt | grep 'AC Power' || true)"
LOW_POWER_MODE="$(pmset -g custom 2>/dev/null | awk '/lowpowermode/ { print $2; exit }')"

SUCCESS_COLOR="${SUCCESS_COLOR:-0xff34C759}"
WARNING_COLOR="${WARNING_COLOR:-0xffFFD60A}"
TEXT_COLOR="${TEXT_COLOR:-0xffddf7ff}"

[ -n "$PERCENTAGE" ] || exit 0

case "$PERCENTAGE" in
  9[0-9]|100)
    ICON=""
    ;;
  [6-8][0-9])
    ICON=""
    ;;
  [3-5][0-9])
    ICON=""
    ;;
  [1-2][0-9])
    ICON=""
    ;;
  *)
    ICON=""
    ;;
esac

ICON_COLOR="$TEXT_COLOR"

if [ "${LOW_POWER_MODE:-0}" = "1" ]; then
  ICON_COLOR="$WARNING_COLOR"
elif [ "$PERCENTAGE" -ge 95 ]; then
  ICON=""
  ICON_COLOR="$SUCCESS_COLOR"
elif [ -n "$CHARGING" ]; then
  ICON=""
fi

sketchybar --set "$NAME" icon="$ICON" icon.color="$ICON_COLOR" label="${PERCENTAGE}%"
