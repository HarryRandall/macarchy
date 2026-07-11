#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/macarchy-metrics-test.XXXXXX")"
FAKE_BIN="$TEST_ROOT/bin"
CONFIG_DIR="$TEST_ROOT/config"

cleanup() {
  if [ -r "$CONFIG_DIR/.state/macmon-stream.pid" ]; then
    kill "$(cat "$CONFIG_DIR/.state/macmon-stream.pid")" 2>/dev/null || true
  fi
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

mkdir -p "$FAKE_BIN" "$CONFIG_DIR/.state" "$CONFIG_DIR/plugins"
ln -s "$REPO_ROOT/sketchybar/plugins/macmon_stream.sh" "$CONFIG_DIR/plugins/macmon_stream.sh"

cat > "$FAKE_BIN/macmon" <<'EOF'
#!/usr/bin/env bash
trap 'exit 0' TERM INT
while :; do
  printf '%s\n' '{"cpu_usage_pct":0.375,"gpu_usage":[500,0.5],"memory":{"ram_usage":4294967296,"ram_total":17179869184},"temp":{"cpu_temp_avg":42.5,"gpu_temp_avg":39.5}}'
  sleep 0.05
done
EOF

cat > "$FAKE_BIN/pgrep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat > "$FAKE_BIN/sketchybar" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$SKETCHYBAR_LOG"
EOF

chmod +x "$FAKE_BIN/macmon" "$FAKE_BIN/pgrep" "$FAKE_BIN/sketchybar"

export CONFIG_DIR
export MACMON_BIN="$FAKE_BIN/macmon"
export PATH="$FAKE_BIN:/usr/bin:/bin"

"$REPO_ROOT/sketchybar/plugins/macmon_stream.sh" --start

for _attempt in 1 2 3 4 5 6 7 8 9 10; do
  [ -s "$CONFIG_DIR/.state/macmon.json" ] && break
  sleep 0.05
done
[ -s "$CONFIG_DIR/.state/macmon.json" ] || fail 'macmon stream did not write a local sample'

first_pid="$(cat "$CONFIG_DIR/.state/macmon-stream.pid")"
"$REPO_ROOT/sketchybar/plugins/macmon_stream.sh" --start
second_pid="$(cat "$CONFIG_DIR/.state/macmon-stream.pid")"
[ "$first_pid" = "$second_pid" ] || fail 'a second sampler was started'

SKETCHYBAR_LOG="$TEST_ROOT/sketchybar.log"
export SKETCHYBAR_LOG
SKETCHYBAR_BIN="$FAKE_BIN/sketchybar" \
  MACMON_DATA_FILE="$CONFIG_DIR/.state/macmon.json" \
  "$REPO_ROOT/sketchybar/plugins/system_metrics.sh"

grep -F 'icon=37.5%' "$SKETCHYBAR_LOG" >/dev/null || fail 'CPU percentage was not formatted'
grep -F 'icon=50.0%' "$SKETCHYBAR_LOG" >/dev/null || fail 'GPU percentage was not formatted'
grep -F 'icon=25.0%' "$SKETCHYBAR_LOG" >/dev/null || fail 'RAM percentage was not calculated'
grep -F 'label= 4.0G' "$SKETCHYBAR_LOG" >/dev/null || fail 'used RAM was not formatted'

stale_sample="$TEST_ROOT/stale.json"
cp "$CONFIG_DIR/.state/macmon.json" "$stale_sample"
touch -t 200001010000 "$stale_sample"
: > "$SKETCHYBAR_LOG"
SKETCHYBAR_BIN="$FAKE_BIN/sketchybar" \
  MACMON_DATA_FILE="$stale_sample" \
  "$REPO_ROOT/sketchybar/plugins/system_metrics.sh"
grep -F 'icon=--.-%' "$SKETCHYBAR_LOG" >/dev/null || fail 'stale metrics were still displayed'

kill "$first_pid" 2>/dev/null || true
for _attempt in 1 2 3 4 5 6 7 8 9 10; do
  [ ! -e "$CONFIG_DIR/.state/macmon-stream.pid" ] && break
  sleep 0.05
done
touch -t 200001010000 "$CONFIG_DIR/.state/macmon.json"
SKETCHYBAR_BIN="$FAKE_BIN/sketchybar" \
  MACMON_DATA_FILE="$CONFIG_DIR/.state/macmon.json" \
  "$REPO_ROOT/sketchybar/plugins/system_metrics.sh"
for _attempt in 1 2 3 4 5 6 7 8 9 10; do
  [ -s "$CONFIG_DIR/.state/macmon-stream.pid" ] && break
  sleep 0.05
done
[ -s "$CONFIG_DIR/.state/macmon-stream.pid" ] || fail 'stale metrics did not restart the macmon stream'
replacement_pid="$(cat "$CONFIG_DIR/.state/macmon-stream.pid")"
[ "$replacement_pid" != "$first_pid" ] || fail 'macmon stream restart reused the stopped process'

mkdir -p "$CONFIG_DIR/icons"
touch \
  "$CONFIG_DIR/icons/cpu.png" \
  "$CONFIG_DIR/icons/gpu-rotated-270.png" \
  "$CONFIG_DIR/icons/ram-rotated-270.png" \
  "$CONFIG_DIR/icons/network-arrows.png"
: > "$SKETCHYBAR_LOG"
PLUGIN_DIR="$REPO_ROOT/sketchybar/plugins" \
  /bin/bash "$REPO_ROOT/sketchybar/items/system_metrics.sh"
for image in cpu.png gpu-rotated-270.png ram-rotated-270.png; do
  grep -F "background.image=$CONFIG_DIR/icons/$image" "$SKETCHYBAR_LOG" >/dev/null \
    || fail "$image was not used for its hardware metric"
done
grep -F 'background.image.scale=0.16' "$SKETCHYBAR_LOG" >/dev/null \
  || fail 'hardware metric images did not use their original scale'
grep -F "background.image=$CONFIG_DIR/icons/network-arrows.png" "$SKETCHYBAR_LOG" >/dev/null \
  || fail 'network-arrows.png was not used for the network metric'
grep -F 'background.image.scale=0.13' "$SKETCHYBAR_LOG" >/dev/null \
  || fail 'network image did not use its original scale'

rm -rf "$CONFIG_DIR/icons"
: > "$SKETCHYBAR_LOG"
PLUGIN_DIR="$REPO_ROOT/sketchybar/plugins" \
  /bin/bash "$REPO_ROOT/sketchybar/items/system_metrics.sh"
for fallback in 'icon=CPU' 'icon=GPU' 'icon=RAM' 'icon=NET'; do
  grep -F "$fallback" "$SKETCHYBAR_LOG" >/dev/null \
    || fail "$fallback was not used when its image was unavailable"
done

mv "$FAKE_BIN/macmon" "$FAKE_BIN/macmon.disabled"
: > "$SKETCHYBAR_LOG"
PLUGIN_DIR="$REPO_ROOT/sketchybar/plugins" \
  /bin/bash "$REPO_ROOT/sketchybar/items/system_metrics.sh"
mv "$FAKE_BIN/macmon.disabled" "$FAKE_BIN/macmon"
grep -F -- '--add item network.text' "$SKETCHYBAR_LOG" >/dev/null \
  || fail 'network metric was hidden when macmon was unavailable'
if grep -F -- '--add item cpu.text' "$SKETCHYBAR_LOG" >/dev/null; then
  fail 'hardware metric placeholders were added without macmon'
fi

printf 'Local macmon stream and metric formatting passed.\n'
