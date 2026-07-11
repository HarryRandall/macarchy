#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/macarchy-yabai-test.XXXXXX")"
FAKE_BIN="$TEST_ROOT/bin"
LOG_FILE="$TEST_ROOT/yabai.log"
JQ_BIN="$(command -v jq)"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

assert_log() {
  grep -F -- "$1" "$LOG_FILE" >/dev/null || fail "missing yabai call: $1"
}

mkdir -p "$FAKE_BIN" "$TEST_ROOT/config/yabai"

cat > "$FAKE_BIN/yabai" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$YABAI_TEST_LOG"

case "$*" in
  '-m query --spaces --space')
    printf '%s\n' '{"index":3}'
    ;;
  '-m query --spaces')
    printf '%s\n' '[{"id":7,"is-native-fullscreen":true}]'
    ;;
  '-m query --windows')
    if [ "${GHOSTTY_TEST_MODE:-0}" = '1' ]; then
      query_count="$(cat "$GHOSTTY_TEST_COUNT" 2>/dev/null || printf '0')"
      query_count=$((query_count + 1))
      printf '%s\n' "$query_count" > "$GHOSTTY_TEST_COUNT"

      if [ "$query_count" -lt 3 ]; then
        printf '%s\n' '[{"id":10,"app":"Ghostty","is-floating":false}]'
      else
        printf '%s\n' '[{"id":10,"app":"Ghostty","is-floating":false},{"id":99,"app":"Ghostty","is-floating":true}]'
      fi
    else
      printf '%s\n' '[{"id":42,"pid":77,"app":"Example","is-minimized":true,"is-floating":false}]'
    fi
    ;;
  '-m query --windows --window 42'|'-m query --windows --window')
    printf '%s\n' '{"id":42,"pid":77,"app":"Example","is-minimized":false,"is-floating":false}'
    ;;
  '-m query --windows --window 99')
    printf '%s\n' '{"id":99,"pid":88,"app":"Ghostty","is-minimized":false,"is-floating":true}'
    ;;
  '-m rule --list')
    printf '%s\n' '[]'
    ;;
esac
EOF

cat > "$FAKE_BIN/open" <<'EOF'
#!/usr/bin/env bash
printf 'open %s\n' "$*" >> "$YABAI_TEST_LOG"
EOF

cat > "$FAKE_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
exit "${YABAI_TEST_SUDO_STATUS:-1}"
EOF

chmod +x "$FAKE_BIN/yabai" "$FAKE_BIN/open" "$FAKE_BIN/sudo"
export PATH="$FAKE_BIN:/usr/bin:/bin"
export YABAI_BIN="$FAKE_BIN/yabai"
export JQ_BIN
export YABAI_CONFIG_DIR="$TEST_ROOT/config/yabai"
export YABAI_TEST_LOG="$LOG_FILE"
export XDG_CACHE_HOME="$TEST_ROOT/cache"

printf '%s\n' '["Example"]' > "$YABAI_CONFIG_DIR/float_state.json"
YABAI_WINDOW_ID=42 "$REPO_ROOT/yabai/apply_float_state.sh"
assert_log '-m window 42 --toggle float'
if grep -F -- '--float' "$LOG_FILE" >/dev/null; then
  fail 'obsolete --float syntax was used'
fi

: > "$LOG_FILE"
YABAI_PROCESS_ID=77 "$REPO_ROOT/yabai/examples/restore_minimized_on_current_space.sh"
expected_order="$(printf '%s\n' \
  '-m window 42 --space 3' \
  '-m window --deminimize 42' \
  '-m window --focus 42')"
actual_order="$(grep '^-m window' "$LOG_FILE")"
[ "$actual_order" = "$expected_order" ] || fail 'move, deminimise and focus calls were out of order'

: > "$LOG_FILE"
printf '%s\n' '[]' > "$YABAI_CONFIG_DIR/float_state.json"
"$REPO_ROOT/yabai/toggle_float_persist.sh"
assert_log '-m window --toggle float'
"$JQ_BIN" -e 'index("Example") != null' "$YABAI_CONFIG_DIR/float_state.json" >/dev/null \
  || fail 'floating app preference was not saved'

: > "$LOG_FILE"
export GHOSTTY_TEST_MODE=1
export GHOSTTY_TEST_COUNT="$TEST_ROOT/ghostty-query-count"
rm -f "$GHOSTTY_TEST_COUNT"
GHOSTTY_WINDOW_POLL_ATTEMPTS=4 \
  GHOSTTY_WINDOW_POLL_DELAY=0 \
  "$REPO_ROOT/yabai/launch_ghostty.sh"
unset GHOSTTY_TEST_MODE GHOSTTY_TEST_COUNT

assert_log 'open -na Ghostty'
assert_log '-m window 99 --toggle float'
assert_log '-m window --focus 99'
if grep -F -- '-m window 10' "$LOG_FILE" >/dev/null; then
  fail 'an existing Ghostty window was selected'
fi
[ "$(cat "$TEST_ROOT/ghostty-query-count")" -ge 3 ] \
  || fail 'Ghostty window creation was not polled'

: > "$LOG_FILE"
"$REPO_ROOT/yabai/sync_float_rules.sh"
assert_log 'manage=off'
if grep -F -- 'grid=' "$LOG_FILE" >/dev/null; then
  fail 'persistent float rule still sets a fixed grid'
fi

: > "$LOG_FILE"
"$REPO_ROOT/yabai/examples/restart_borders_after_fullscreen.sh"
grep -F '7' "$XDG_CACHE_HOME/yabai/borders-native-fullscreen-spaces" >/dev/null \
  || fail 'fullscreen helper did not record its initial state'

: > "$LOG_FILE"
YABAI_TEST_SUDO_STATUS=1 "$REPO_ROOT/yabai/yabairc"
assert_log '-m signal --remove macarchy_load_sa'
assert_log '-m signal --remove macarchy_space_changed'
assert_log '-m signal --remove macarchy_restore_minimized'
assert_log '-m signal --remove borders_fullscreen_space_created'
assert_log '-m signal --remove borders_fullscreen_space_destroyed'
assert_log '-m signal --remove borders_fullscreen_space_changed'
assert_log '-m signal --remove macarchy_window_destroyed'
assert_log '-m signal --remove macarchy_window_minimized'
if grep -F -- 'event=application_activated' "$LOG_FILE" >/dev/null; then
  fail 'minimised-window restoration was enabled by default'
fi
window_created_signal="$(grep -F 'label=macarchy_window_created' "$LOG_FILE")"
case "$window_created_signal" in
  *trigger_sketchybar*) fail 'window creation still requested a duplicate full label refresh' ;;
esac
if grep -F -- 'label=macarchy_load_sa' "$LOG_FILE" >/dev/null; then
  fail 'scripting-addition signal was added without a working sudoers rule'
fi
printf 'yabai helper command ordering and safety checks passed.\n'
