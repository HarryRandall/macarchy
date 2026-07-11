#!/bin/bash

METRIC_FONT="Menlo:Bold:10.0"
BIG_ICON_FONT="SF Pro:Semibold:15.0"
COLOR="${TEXT_COLOR:-0xffffffff}"
BOX_BORDER="0x55ffffff"
MACMON_BIN="$(command -v macmon 2>/dev/null || true)"

# Fixed-width boxes sized around common metric strings.
CHAR_W=5
VAL_CHARS=5 # "99.9%", "15.8G", "45.0°"
NET_CHARS=8 # "99.9MB/s"

VAL_TEXT_W=$((VAL_CHARS * CHAR_W))
NET_TEXT_W=$((NET_CHARS * CHAR_W - 3))

VAL_W=$((VAL_TEXT_W + 10))
NET_W=$((NET_TEXT_W + 21))
METRIC_ICON_W=30
RAM_ICON_W=24
NETWORK_ICON_W=17

# Horizontal gap between adjacent metric brackets, applied as padding_left
# on the bracket itself (outside the border).
BOX_GAP=11

set_text_item() {
  local name="$1" text_w="$2" pad_left="$3"
  local icon_y="${4:-6}" label_y="${5:--6}"

  sketchybar --set "$name.text" \
    background.border_width=0 \
    background.color=0x00000000 \
    background.padding_left=0 \
    background.padding_right=0 \
    padding_left=0 \
    padding_right=4 \
    width="$text_w" \
    icon.font="$METRIC_FONT" \
    icon.color="$COLOR" \
    icon.align=left \
    icon.y_offset="$icon_y" \
    icon.padding_left=2 \
    icon.padding_right=0 \
    label.font="$METRIC_FONT" \
    label.color="$COLOR" \
    label.align=left \
    label.y_offset="$label_y" \
    label.padding_left="-$((pad_left + 5))" \
    label.padding_right=0
}

set_bracket_box() {
  local bracket="$1"
  sketchybar --set "$bracket" \
    background.drawing=off \
    background.color=0x00000000 \
    background.border_color="$BOX_BORDER" \
    background.border_width=0 \
    background.corner_radius=5 \
    background.height=28 \
    padding_left=0 \
    padding_right=0
}

add_spacer() {
  local name="$1"
  sketchybar --add item "$name" right \
    --set "$name" \
    background.drawing=off \
    icon.drawing=off \
    label.drawing=off \
    width="$BOX_GAP" \
    padding_left=0 \
    padding_right=0
}

stacked_metric_icon() {
  local name="$1" glyph="$2" item_w="$3" text_w="$4"
  local icon_w="${5:-$METRIC_ICON_W}"

  sketchybar --add item "$name.text" right
  set_text_item "$name" "$item_w" "$text_w"
  sketchybar --add item "$name.icon" right \
    --set "$name.icon" \
    background.border_width=0 \
    background.drawing=off \
    background.color=0x00000000 \
    padding_left=0 \
    padding_right=0 \
    width="$icon_w" \
    icon="$glyph" \
    icon.font="$METRIC_FONT" \
    icon.color="$COLOR" \
    icon.padding_left=4 \
    icon.padding_right=0 \
    label.drawing=off \
    --add bracket "$name.bracket" "$name.icon" "$name.text"
  set_bracket_box "$name.bracket"
}

stacked_network() {
  sketchybar --add item network.text right
  set_text_item network "$NET_W" "$NET_TEXT_W" 5 -4
  sketchybar --set network.text \
    icon.padding_left=0 \
    update_freq=5 \
    script="$PLUGIN_DIR/network_speed.sh"
  sketchybar --add item network.icon right \
    --set network.icon \
    background.border_width=0 \
    background.color=0x00000000 \
    background.drawing=off \
    padding_left=0 \
    padding_right=0 \
    width="$NETWORK_ICON_W" \
    icon="NET" \
    icon.font="$METRIC_FONT" \
    icon.color="$COLOR" \
    icon.padding_left=2 \
    icon.padding_right=0 \
    label.drawing=off \
    --add bracket network.bracket network.icon network.text
  set_bracket_box network.bracket
}

add_system_metrics_updater() {
  # macmon's pipe mode keeps metrics local instead of opening an HTTP port.
  "$PLUGIN_DIR/macmon_stream.sh" --start

  # One hidden item fetches macmon once and updates all three visible metrics.
  sketchybar --add item system_metrics_updater right \
    --set system_metrics_updater \
      drawing=off \
      width=0 \
      updates=on \
      update_freq=5 \
      script="$PLUGIN_DIR/system_metrics.sh" \
    --subscribe system_metrics_updater system_woke
}

# Right-positioned items render in reverse add order. The hardware tiles are
# optional because macmon supports Apple Silicon only; network speed works on
# every supported Mac.
if [ -n "$MACMON_BIN" ]; then
  stacked_metric_icon cpu CPU "$VAL_W" "$VAL_TEXT_W"
  add_spacer gap.cpu
  stacked_metric_icon gpu GPU "$VAL_W" "$VAL_TEXT_W"
  add_spacer gap.gpu
  stacked_metric_icon ram RAM "$VAL_W" "$VAL_TEXT_W" "$RAM_ICON_W"
  add_spacer gap.ram
fi
stacked_network
if [ -n "$MACMON_BIN" ]; then
  add_system_metrics_updater
fi
