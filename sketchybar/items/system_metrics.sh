#!/bin/bash

METRIC_FONT="Menlo:Bold:10.0"
BIG_ICON_FONT="SF Pro:Semibold:15.0"
COLOR="${TEXT_COLOR:-0xffffffff}"
BOX_BORDER="0x55ffffff"
ICONS_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}/icons"

# Fixed-width boxes sized around the longest capped metric strings.
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
METRIC_ICON_SCALE=0.16
NETWORK_ICON_SCALE=0.13

# Horizontal gap between adjacent metric brackets, applied as padding_left
# on the bracket itself (outside the border).
BOX_GAP=11

set_text_item() {
  local name="$1" text_w="$2" pad_left="$3" freq="$4" script="$5"
  local icon_y="${6:-6}" label_y="${7:--6}"

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
    label.padding_right=0 \
    update_freq="$freq" \
    script="$script"
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

stacked_metric_image() {
  local name="$1" image="$2" item_w="$3" text_w="$4" freq="$5" script="$6"
  local icon_w="${7:-$METRIC_ICON_W}"

  sketchybar --add item "$name.text" right
  set_text_item "$name" "$item_w" "$text_w" "$freq" "$script"
  sketchybar --add item "$name.icon" right \
    --set "$name.icon" \
    background.border_width=0 \
    background.drawing=on \
    background.image="$image" \
    background.image.scale="$METRIC_ICON_SCALE" \
    background.color=0x00000000 \
    padding_left=0 \
    padding_right=0 \
    width="$icon_w" \
    icon.drawing=off \
    label.drawing=off \
    --add bracket "$name.bracket" "$name.icon" "$name.text"
  set_bracket_box "$name.bracket"
}

stacked_network() {
  sketchybar --add item network.text right
  set_text_item network "$NET_W" "$NET_TEXT_W" 5 "$PLUGIN_DIR/network_speed.sh" 5 -4
  sketchybar --set network.text icon.padding_left=0
  sketchybar --add item network.icon right \
    --set network.icon \
    background.border_width=0 \
    background.color=0x00000000 \
    background.drawing=on \
    background.image="$ICONS_DIR/network-arrows.png" \
    background.image.scale="$NETWORK_ICON_SCALE" \
    padding_left=0 \
    padding_right=0 \
    width="$NETWORK_ICON_W" \
    icon.drawing=off \
    label.drawing=off \
    --add bracket network.bracket network.icon network.text
  set_bracket_box network.bracket
}

# Right-positioned items render in reverse add order.
# Target LTR within this group: network | ram | gpu | cpu
stacked_metric_image cpu "$ICONS_DIR/cpu.png" "$VAL_W" "$VAL_TEXT_W" 5 "$PLUGIN_DIR/system_metrics.sh"
add_spacer gap.cpu
stacked_metric_image gpu "$ICONS_DIR/gpu-rotated-270.png" "$VAL_W" "$VAL_TEXT_W" 5 "$PLUGIN_DIR/system_metrics.sh"
add_spacer gap.gpu
stacked_metric_image ram "$ICONS_DIR/ram-rotated-270.png" "$VAL_W" "$VAL_TEXT_W" 10 "$PLUGIN_DIR/system_metrics.sh" "$RAM_ICON_W"
add_spacer gap.ram
stacked_network
