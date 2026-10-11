#!/bin/bash
# One snapshot, one diff, one sketchybar call.
#
# Every space item used to carry script=space.sh, so a single space change fanned
# out into one process chain per item (10 of them), and each of those re-set all
# 10 items. That was ~575ms of serialised work and ~10 full bar redraws per
# switch, which is what made swapping feel laggy and what kept re-compositing
# anything layered over the bar (the volume HUD).
#
# Now a single hidden item drives the render: two yabai queries, a diff against
# the last applied state, and at most one sketchybar invocation carrying only the
# items that actually changed. Overlapping triggers set a dirty flag and exit
# instead of queueing another full render.

BAR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$BAR_DIR/lib.sh"
YABAI_BIN="$(macarchy_find yabai)"
SKETCHYBAR_BIN="$(macarchy_find sketchybar)"
JQ_BIN="$(macarchy_find jq)"
STATE_DIR="$MACARCHY_STATE"
CACHE_FILE="$STATE_DIR/space_render"
LOCK_DIR="$STATE_DIR/space_render.lock"
DIRTY_FILE="$STATE_DIR/space_render.dirty"
MAX_FALLBACK_SPACES="${MAX_FALLBACK_SPACES:-10}"

# shellcheck source=/dev/null
source "$BAR_DIR/plugins/icon_map.sh"

mkdir -p "$STATE_DIR"

# Properties that never change once the item exists. Appended to $set_args.
#
# script="" + updates=off is the whole point of this design: sketchybar gives
# every space item a default script (icon.highlight=$SELECTED) and runs it on
# every space change, so leaving script= unset still costs one fork per item per
# switch. These items are driven entirely by the bulk render, so they never need
# to run one.
append_static_props() {
  local sid="$1"
  set_args[${#set_args[@]}]="space=$sid"
  set_args[${#set_args[@]}]="script="
  set_args[${#set_args[@]}]="updates=off"
  set_args[${#set_args[@]}]="icon=$sid"
  set_args[${#set_args[@]}]="icon.font=SF Pro:Semibold:12.0"
  set_args[${#set_args[@]}]="padding_left=2"
  set_args[${#set_args[@]}]="label.font=sketchybar-app-font:Regular:13.0"
  set_args[${#set_args[@]}]="label.padding_right=20"
  set_args[${#set_args[@]}]="label.y_offset=-1"
  set_args[${#set_args[@]}]="click_script=$YABAI_BIN -m space --focus $sid"
}

# index <TAB> is-visible <TAB> app<US>app<US>app  — one line per existing space.
snapshot() {
  [ -x "$YABAI_BIN" ] || return 1

  local spaces windows
  spaces="$("$YABAI_BIN" -m query --spaces 2>/dev/null)" || return 1
  [ -n "$spaces" ] || return 1
  windows="$("$YABAI_BIN" -m query --windows 2>/dev/null)" || windows='[]'
  [ -n "$windows" ] || windows='[]'

  printf '%s\n%s\n' "$spaces" "$windows" | "$JQ_BIN" -r -s '
    .[0] as $spaces
    | (.[1] | map(select(
        .app
        and .role == "AXWindow"
        and .subrole == "AXStandardWindow"
        and .["has-ax-reference"] == true
        and .["is-minimized"] == false
        and .["is-hidden"] == false
        and ((."is-sticky" // false) == false)
      ))) as $windows
    | $spaces
    | map(select(.index != null))
    | sort_by(.index)
    | .[]
    | . as $space
    | (
        $windows
        | map(select(.space == $space.index and .display == $space.display))
        | sort_by(.frame.x, .frame.y, .["stack-index"], .id)
        | map(.app)
        | join("\u001f")
      ) as $apps
    | "\($space.index)\t\(if .["is-visible"] then 1 else 0 end)\t\($apps)"
  ' 2>/dev/null
}

# Apps the generated icon map has never heard of — locally built ones, mostly —
# otherwise fall through to :default:, which renders as a bare square.
# Kept here rather than in icon_map.sh because that file is generated.
local_icon_override() {
  case "$1" in
    "Macarchy Settings"|"MacarchySettings") icon_result=":gear:" ;;
    *) return 1 ;;
  esac
  return 0
}

# Sets $strip_result. Deliberately not a command substitution: at one fork per
# visible space that was a measurable slice of every render.
icon_strip_for() {
  local apps="$1"
  local app
  local old_ifs="$IFS"

  if [ -z "$apps" ]; then
    strip_result=" —"
    return 0
  fi

  strip_result=" "
  IFS=$'\037'
  for app in $apps; do
    [ -n "$app" ] || continue
    local_icon_override "$app" || __icon_map "$app"
    strip_result="$strip_result ${icon_result:-:default:}"
  done
  IFS="$old_ifs"
}

# render            -> diff against the cache, set only what changed
# render create     -> add every item already in its final state, one invocation
#
# create mode matters on --reload (which is what a theme switch does): adding the
# items one sketchybar call at a time made them sweep in left to right, and every
# item was briefly visible before the render could hide the Spaces that do not
# exist. Adding and styling all ten in a single batch means the bar never paints
# an intermediate state.
render() {
  local mode="${1:-update}"
  local accent="${ACCENT_COLOR:-0xffffffff}"
  local text="${TEXT_COLOR:-0xffffffff}"
  local accent_rgb="${accent#0x}"
  accent_rgb="${accent_rgb#\#}"
  local active_bg="0x1a${accent_rgb: -6}"

  local lines
  lines="$(snapshot)" || return 0
  [ -n "$lines" ] || return 0

  local sid idx visible apps present signature old strip strip_result
  local drawing bg_drawing bg_color border_width border_color colour
  local set_args new_cache
  set_args=()
  new_cache=()

  # Load the previously applied state into OLD_<n> vars (bash 3.2: no assoc arrays).
  sid=1
  while [ "$sid" -le "$MAX_FALLBACK_SPACES" ]; do
    eval "OLD_$sid="
    sid=$((sid + 1))
  done
  if [ "$mode" != create ] && [ -f "$CACHE_FILE" ]; then
    while IFS=$'\t' read -r idx signature; do
      case "$idx" in ''|*[!0-9]*) continue ;; esac
      [ "$idx" -ge 1 ] && [ "$idx" -le "$MAX_FALLBACK_SPACES" ] || continue
      eval "OLD_$idx=\$signature"
    done < "$CACHE_FILE"
  fi

  sid=1
  while [ "$sid" -le "$MAX_FALLBACK_SPACES" ]; do
    present=0
    visible=0
    apps=""

    while IFS=$'\t' read -r idx visible apps; do
      if [ "$idx" = "$sid" ]; then
        present=1
        break
      fi
    done <<< "$lines"

    if [ "$present" = 1 ]; then
      drawing=on
      icon_strip_for "$apps"
      strip="$strip_result"
      if [ "$visible" = 1 ]; then
        bg_drawing=on
        bg_color="$active_bg"
        border_width=1
        border_color="$accent"
        colour="$accent"
      else
        bg_drawing=off
        bg_color=0x00000000
        border_width=0
        border_color=0x00000000
        colour="$text"
      fi
    else
      drawing=off
      strip=" —"
      bg_drawing=off
      bg_color=0x00000000
      border_width=0
      border_color=0x00000000
      colour="$text"
    fi

    signature="$drawing|$bg_drawing|$bg_color|$border_width|$border_color|$colour|$strip"
    new_cache[${#new_cache[@]}]="$sid"$'\t'"$signature"

    eval "old=\$OLD_$sid"
    if [ "$mode" = create ]; then
      set_args[${#set_args[@]}]="--add"
      set_args[${#set_args[@]}]="space"
      set_args[${#set_args[@]}]="space.$sid"
      set_args[${#set_args[@]}]="left"
    fi
    if [ "$mode" = create ] || [ "$old" != "$signature" ]; then
      set_args[${#set_args[@]}]="--set"
      set_args[${#set_args[@]}]="space.$sid"
      [ "$mode" = create ] && append_static_props "$sid"
      # Reasserted on every touch: sketchybar flips updates back on for space
      # items whose Space exists, and a default script comes back with it.
      set_args[${#set_args[@]}]="script="
      set_args[${#set_args[@]}]="updates=off"
      set_args[${#set_args[@]}]="drawing=$drawing"
      set_args[${#set_args[@]}]="background.drawing=$bg_drawing"
      set_args[${#set_args[@]}]="background.color=$bg_color"
      set_args[${#set_args[@]}]="background.border_width=$border_width"
      set_args[${#set_args[@]}]="background.border_color=$border_color"
      set_args[${#set_args[@]}]="label.color=$colour"
      set_args[${#set_args[@]}]="icon.color=$colour"
      set_args[${#set_args[@]}]="label=$strip"
    fi

    sid=$((sid + 1))
  done

  # Nothing changed: no sketchybar call at all, so no bar redraw.
  if [ "${#set_args[@]}" -gt 0 ]; then
    if ! "$SKETCHYBAR_BIN" "${set_args[@]}" >/dev/null 2>&1; then
      # An update --set fails when the space items don't exist: on --reload the
      # --reconcile can lose the lock to an event render and exit without ever
      # creating them, which left the left side empty until the next reload.
      # Rebuild them instead of failing the same way on every event.
      [ "$mode" = create ] && return 0
      render create
      return
    fi
  fi

  printf '%s\n' "${new_cache[@]}" > "$CACHE_FILE.tmp" && mv -f "$CACHE_FILE.tmp" "$CACHE_FILE"
}

# Coalesce bursts: a render already in flight absorbs the extra triggers instead
# of each one spawning its own full pass.
run_coalesced() {
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    # Clear a lock orphaned by a killed run; otherwise just flag and leave.
    if [ -n "$(find "$LOCK_DIR" -maxdepth 0 -mmin +1 2>/dev/null)" ]; then
      rmdir "$LOCK_DIR" 2>/dev/null || true
      mkdir "$LOCK_DIR" 2>/dev/null || { : > "$DIRTY_FILE"; return 0; }
    else
      : > "$DIRTY_FILE"
      return 0
    fi
  fi
  trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT INT TERM

  while :; do
    rm -f "$DIRTY_FILE"
    render "${RENDER_MODE:-update}"
    RENDER_MODE=update
    [ -e "$DIRTY_FILE" ] || break
  done
}

case "${1:-}" in
  --reconcile)
    rm -f "$CACHE_FILE"
    RENDER_MODE=create
    run_coalesced
    exit 0
    ;;
  --space-ids)
    snapshot | cut -f1
    exit 0
    ;;
  --recolor)
    # A theme change only swaps ACCENT/TEXT. The cache already records which
    # Space is highlighted and what every label says, so this rewrites the colour
    # fields straight off it — no yabai queries, no icon map, one sketchybar call.
    [ -f "$CACHE_FILE" ] || { run_coalesced; exit 0; }
    accent="${ACCENT_COLOR:-0xffffffff}"
    text="${TEXT_COLOR:-0xffffffff}"
    accent_rgb="${accent#0x}"
    accent_rgb="${accent_rgb#\#}"
    active_bg="0x1a${accent_rgb: -6}"

    set_args=()
    new_cache=()
    while IFS=$'\t' read -r idx signature; do
      case "$idx" in ''|*[!0-9]*) continue ;; esac
      old_ifs="$IFS"; IFS='|'; set -- $signature; IFS="$old_ifs"
      drawing="$1"; bg_drawing="$2"
      # $7 onwards is the label, which can itself contain the separator.
      strip="${signature#*|*|*|*|*|*|}"

      if [ "$bg_drawing" = on ]; then
        bg_color="$active_bg"; border_width=1; border_color="$accent"; colour="$accent"
      else
        bg_color=0x00000000; border_width=0; border_color=0x00000000; colour="$text"
      fi

      signature="$drawing|$bg_drawing|$bg_color|$border_width|$border_color|$colour|$strip"
      new_cache[${#new_cache[@]}]="$idx"$'\t'"$signature"
      set_args[${#set_args[@]}]="--set"
      set_args[${#set_args[@]}]="space.$idx"
      set_args[${#set_args[@]}]="background.color=$bg_color"
      set_args[${#set_args[@]}]="background.border_color=$border_color"
      set_args[${#set_args[@]}]="label.color=$colour"
      set_args[${#set_args[@]}]="icon.color=$colour"
    done < "$CACHE_FILE"

    if [ "${#set_args[@]}" -gt 0 ]; then
      "$SKETCHYBAR_BIN" "${set_args[@]}" >/dev/null 2>&1 || exit 0
      printf '%s\n' "${new_cache[@]}" > "$CACHE_FILE.tmp" && mv -f "$CACHE_FILE.tmp" "$CACHE_FILE"
    fi
    exit 0
    ;;
  --dump)
    # Ground truth when the bar looks wrong: what we believe we applied, versus
    # what sketchybar is actually holding.
    echo "== theme =="
    echo "ACCENT_COLOR=$ACCENT_COLOR TEXT_COLOR=$TEXT_COLOR BAR_COLOR=${BAR_COLOR:-unset}"
    echo "== yabai =="
    snapshot
    echo "== cache (what we last applied) =="
    cat "$CACHE_FILE" 2>/dev/null || echo "(none)"
    echo "== live bar =="
    "$SKETCHYBAR_BIN" --query bar | "$JQ_BIN" -r '"bar color=\(.color) blur=\(.blur_radius) height=\(.height) hidden=\(.hidden)"'
    sid=1
    while [ "$sid" -le "$MAX_FALLBACK_SPACES" ]; do
      "$SKETCHYBAR_BIN" --query "space.$sid" 2>/dev/null | "$JQ_BIN" -r --arg n "$sid" '
        "space.\($n) drawing=\(.geometry.drawing) bg.drawing=\(.geometry.background.drawing) bg=\(.geometry.background.color) border=\(.geometry.background.border_width)/\(.geometry.background.border_color) icon=\(.icon.color)/hl=\(.icon.highlight) label=\(.label.color)/hl=\(.label.highlight) script=\"\(.scripting.script)\" updates=\(.scripting.updates) text=\"\(.label.value)\""'
      sid=$((sid + 1))
    done
    exit 0
    ;;
esac

run_coalesced
