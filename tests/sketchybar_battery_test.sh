#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/macarchy-battery-test.XXXXXX")"
FAKE_BIN="$TEST_ROOT/bin"
SKETCHYBAR_LOG="$TEST_ROOT/sketchybar.log"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

mkdir -p "$FAKE_BIN"

cat > "$FAKE_BIN/pmset" <<'EOF'
#!/usr/bin/env bash

case "$*" in
  '-g batt')
    printf "Now drawing from 'AC Power'\n"
    printf ' -InternalBattery-0 (id=1)\t%s%%; not charging; present: true\n' "$BATTERY_TEST_PERCENT"
    ;;
  '-g custom')
    printf 'AC Power:\n'
    printf ' lowpowermode %s\n' "$BATTERY_TEST_LOW_POWER"
    ;;
esac
EOF

cat > "$FAKE_BIN/sketchybar" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$SKETCHYBAR_LOG"
EOF

chmod +x "$FAKE_BIN/pmset" "$FAKE_BIN/sketchybar"
export PATH="$FAKE_BIN:/usr/bin:/bin"
export CONFIG_DIR="$REPO_ROOT/sketchybar"
export NAME=battery
export SKETCHYBAR_LOG

run_case() {
  local percentage="$1" low_power="$2" expected_colour="$3"

  : > "$SKETCHYBAR_LOG"
  BATTERY_TEST_PERCENT="$percentage" \
    BATTERY_TEST_LOW_POWER="$low_power" \
    "$REPO_ROOT/sketchybar/plugins/battery.sh"

  grep -F "icon.color=$expected_colour" "$SKETCHYBAR_LOG" >/dev/null \
    || fail "unexpected colour for battery at $percentage per cent with mode $low_power"
}

run_case 50 2 0xffFFD60A
run_case 5 2 0xffff453a
run_case 50 0 0xffffffff

printf 'SketchyBar battery power-mode colours passed.\n'
