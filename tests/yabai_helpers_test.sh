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
  '-m query --windows')
    printf '%s\n' '[{"id":42,"pid":77,"app":"Example","is-minimized":true,"is-floating":false}]'
    ;;
  '-m query --windows --window 42'|'-m query --windows --window')
    printf '%s\n' '{"id":42,"pid":77,"app":"Example","is-minimized":false,"is-floating":false}'
    ;;
  '-m rule --list')
    printf '%s\n' '[]'
    ;;
esac
EOF

cat > "$FAKE_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
exit "${YABAI_TEST_SUDO_STATUS:-1}"
EOF

chmod +x "$FAKE_BIN/yabai" "$FAKE_BIN/sudo"
export PATH="$FAKE_BIN:/usr/bin:/bin"
export YABAI_BIN="$FAKE_BIN/yabai"
export JQ_BIN
export YABAI_CONFIG_DIR="$TEST_ROOT/config/yabai"
export YABAI_TEST_LOG="$LOG_FILE"

printf '%s\n' '["Example"]' > "$YABAI_CONFIG_DIR/float_state.json"
YABAI_WINDOW_ID=42 "$REPO_ROOT/yabai/apply_float_state.sh"
assert_log '-m window 42 --toggle float'
if grep -F -- '--float' "$LOG_FILE" >/dev/null; then
  fail 'obsolete --float syntax was used'
fi

: > "$LOG_FILE"
YABAI_PROCESS_ID=77 "$REPO_ROOT/yabai/restore_minimized_on_current_space.sh"
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
"$REPO_ROOT/yabai/sync_float_rules.sh"
assert_log 'manage=off'
if grep -F -- 'grid=' "$LOG_FILE" >/dev/null; then
  fail 'persistent float rule still sets a fixed grid'
fi

: > "$LOG_FILE"
YABAI_TEST_SUDO_STATUS=1 "$REPO_ROOT/yabai/yabairc"
assert_log '-m signal --remove macarchy_load_sa'
if grep -F -- 'label=macarchy_load_sa' "$LOG_FILE" >/dev/null; then
  fail 'scripting-addition signal was added without a working sudoers rule'
fi

printf 'yabai helper command ordering and safety checks passed.\n'
