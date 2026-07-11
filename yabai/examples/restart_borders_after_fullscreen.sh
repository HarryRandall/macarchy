#!/usr/bin/env bash
set -euo pipefail

YABAI_BIN="$(command -v "${YABAI_BIN:-yabai}" 2>/dev/null || true)"
JQ_BIN="$(command -v "${JQ_BIN:-jq}" 2>/dev/null || true)"
BREW_BIN="$(command -v "${BREW_BIN:-brew}" 2>/dev/null || true)"
[ -n "$YABAI_BIN" ] && [ -n "$JQ_BIN" ] || exit 0

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/yabai"
STATE_FILE="$CACHE_DIR/borders-native-fullscreen-spaces"
STAMP_FILE="$CACHE_DIR/borders-restart-after-fullscreen.stamp"
LOCK_DIR="$CACHE_DIR/borders-restart-after-fullscreen.lock"
mkdir -p "$CACHE_DIR"

spaces_json="$("$YABAI_BIN" -m query --spaces 2>/dev/null || printf '[]')"
current_ids="$(
  "$JQ_BIN" -r '.[] | select(."is-native-fullscreen" == true) | .id' <<<"$spaces_json" \
    | sort -n \
    | tr '\n' ' ' \
    | sed 's/[[:space:]]*$//'
)"
previous_ids="$(cat "$STATE_FILE" 2>/dev/null || true)"
state_tmp="$STATE_FILE.$$"
printf '%s\n' "$current_ids" > "$state_tmp"
mv "$state_tmp" "$STATE_FILE"

restart_needed=false
current_padded=" $current_ids "
for space_id in $previous_ids; do
  case "$current_padded" in
    *" $space_id "*) ;;
    *) restart_needed=true ;;
  esac
done

[ "$restart_needed" = "true" ] || exit 0

(
  sleep 0.4

  mkdir "$LOCK_DIR" 2>/dev/null || exit 0
  trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

  now="$(date +%s)"
  last="$(cat "$STAMP_FILE" 2>/dev/null || printf '0')"
  if [ "$((now - last))" -lt 3 ]; then
    exit 0
  fi

  printf '%s\n' "$now" > "$STAMP_FILE"
  launchctl kickstart -k "gui/$(id -u)/homebrew.mxcl.borders" >/dev/null 2>&1 \
    || { [ -n "$BREW_BIN" ] && "$BREW_BIN" services restart borders >/dev/null 2>&1; } \
    || true
) &
