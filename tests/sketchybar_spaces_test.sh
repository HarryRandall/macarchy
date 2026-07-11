#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/macarchy-spaces-test.XXXXXX")"
FAKE_BIN="$TEST_ROOT/bin"
STATE_DIR="$TEST_ROOT/state"
SKETCHYBAR_LOG="$TEST_ROOT/sketchybar.log"
JQ_BIN="$(command -v jq)"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

mkdir -p "$FAKE_BIN" "$STATE_DIR"
: > "$SKETCHYBAR_LOG"

cat > "$FAKE_BIN/yabai" <<'EOF'
#!/usr/bin/env bash

if [ "${SPACE_TEST_QUERY_FAIL:-0}" = '1' ]; then
  exit 1
fi

case "$*" in
  '-m query --spaces')
    if [ "${SPACE_TEST_FULL_QUERY_TRUNCATED:-0}" = '1' ]; then
      printf '%s\n' '['
    else
      printf '%s\n' '[{"index":1},{"index":3}]'
    fi
    ;;
  '-m query --spaces --display 1')
    printf '%s\n' '[{"index":1},{"index":3}]'
    ;;
  '-m query --spaces --display 2')
    exit 1
    ;;
  '-m query --spaces --space 1')
    printf '%s\n' '{"index":1,"display":1}'
    ;;
  '-m query --spaces --space 3')
    printf '%s\n' '{"index":3,"display":1}'
    ;;
  '-m query --windows --space 1')
    printf '%s\n' '[]'
    ;;
  '-m query --windows --space 3')
    printf '%s\n' '[{"app":"ghostty","space":3,"display":1,"role":"","root-window":true,"has-ax-reference":false,"is-minimized":false,"is-hidden":false,"is-sticky":false,"frame":{"x":0,"y":0},"stack-index":0,"id":99}]'
    ;;
esac
EOF

cat > "$FAKE_BIN/sketchybar" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$SKETCHYBAR_LOG"
EOF

chmod +x "$FAKE_BIN/yabai" "$FAKE_BIN/sketchybar"
export PATH="$FAKE_BIN:/usr/bin:/bin"
export CONFIG_DIR="$REPO_ROOT/sketchybar"
export SKETCHYBAR_STATE_DIR="$STATE_DIR"
export SKETCHYBAR_LOG
export JQ_BIN

YABAI_BIN=/definitely/missing \
  "$REPO_ROOT/sketchybar/plugins/space_windows.sh" --reconcile
[ ! -s "$SKETCHYBAR_LOG" ] || fail 'space items were added without yabai'

YABAI_BIN="$FAKE_BIN/yabai" \
  "$REPO_ROOT/sketchybar/plugins/space_windows.sh" --reconcile
grep -F -- '--add space space.1 left' "$SKETCHYBAR_LOG" >/dev/null \
  || fail 'Space 1 was not added'
grep -F -- '--add space space.3 left' "$SKETCHYBAR_LOG" >/dev/null \
  || fail 'Space 3 was not added'
if grep -F -- '--add space space.2 left' "$SKETCHYBAR_LOG" >/dev/null; then
  fail 'a non-existent fallback Space was added'
fi

: > "$SKETCHYBAR_LOG"
rm -f "$STATE_DIR/space_items"
SPACE_TEST_FULL_QUERY_TRUNCATED=1 \
  YABAI_BIN="$FAKE_BIN/yabai" \
  "$REPO_ROOT/sketchybar/plugins/space_windows.sh" --reconcile
grep -F -- '--add space space.1 left' "$SKETCHYBAR_LOG" >/dev/null \
  || fail 'per-display fallback did not recover from a truncated yabai response'

: > "$SKETCHYBAR_LOG"
SPACE_TEST_QUERY_FAIL=1 \
  YABAI_BIN="$FAKE_BIN/yabai" \
  "$REPO_ROOT/sketchybar/plugins/space_windows.sh" --reconcile
[ ! -s "$SKETCHYBAR_LOG" ] || fail 'a transient yabai failure changed the Space items'

: > "$SKETCHYBAR_LOG"
SENDER=space_windows_change \
  INFO='{"space":3,"apps":{}}' \
  YABAI_BIN="$FAKE_BIN/yabai" \
  "$REPO_ROOT/sketchybar/plugins/space_windows.sh"
grep -F -- ':ghostty:' "$SKETCHYBAR_LOG" >/dev/null \
  || fail 'the changed Space was not refreshed'
if grep -F -- '--set space.1 label=' "$SKETCHYBAR_LOG" >/dev/null; then
  fail 'an unchanged Space was needlessly redrawn'
fi

printf 'SketchyBar Space reconciliation passed.\n'
