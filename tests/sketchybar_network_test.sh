#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/macarchy-network-test.XXXXXX")"
FAKE_BIN="$TEST_ROOT/bin"
CONFIG_DIR="$TEST_ROOT/config"
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

cat > "$FAKE_BIN/route" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF

cat > "$FAKE_BIN/ifconfig" <<'EOF'
#!/usr/bin/env bash
cat <<'OUTPUT'
en0: flags=0
        inet 192.0.2.1 netmask 0xffffff00
        status: inactive
en7: flags=1
        inet 198.51.100.2 netmask 0xffffff00
        status: active
lo0: flags=1
        inet 127.0.0.1 netmask 0xff000000
        status: active
OUTPUT
EOF

cat > "$FAKE_BIN/date" <<'EOF'
#!/usr/bin/env bash
count="$(cat "$NETWORK_DATE_COUNT" 2>/dev/null || printf '0')"
count=$((count + 1))
printf '%s\n' "$count" > "$NETWORK_DATE_COUNT"
if [ "$count" -eq 1 ]; then
  printf '100\n'
else
  printf '105\n'
fi
EOF

cat > "$FAKE_BIN/netstat" <<'EOF'
#!/usr/bin/env bash
count="$(cat "$NETWORK_COUNTER_COUNT" 2>/dev/null || printf '0')"
count=$((count + 1))
printf '%s\n' "$count" > "$NETWORK_COUNTER_COUNT"
if [ "$count" -eq 1 ]; then
  rx=1000000
  tx=2000000
else
  rx=6242880
  tx=7242880
fi

printf 'Name Mtu Network Address Ipkts Ierrs Ibytes Opkts Oerrs Obytes Coll\n'
printf 'en7 1500 link addr 1 0 %s 1 0 %s 0\n' "$rx" "$tx"
printf 'en7 1500 inet addr 1 - %s 1 - %s -\n' "$rx" "$tx"
printf 'en7 1500 inet6 addr 1 - %s 1 - %s -\n' "$rx" "$tx"
EOF

cat > "$FAKE_BIN/sketchybar" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$SKETCHYBAR_LOG"
EOF

chmod +x "$FAKE_BIN/date" "$FAKE_BIN/ifconfig" "$FAKE_BIN/netstat" \
  "$FAKE_BIN/route" "$FAKE_BIN/sketchybar"
export PATH="$FAKE_BIN:/usr/bin:/bin"
export CONFIG_DIR
export NETWORK_DATE_COUNT="$TEST_ROOT/date-count"
export NETWORK_COUNTER_COUNT="$TEST_ROOT/counter-count"
export SKETCHYBAR_BIN="$FAKE_BIN/sketchybar"
export SKETCHYBAR_LOG

"$REPO_ROOT/sketchybar/plugins/network_speed.sh"
"$REPO_ROOT/sketchybar/plugins/network_speed.sh"

read -r _ interface _ _ < "$CONFIG_DIR/.state/network_speed"
[ "$interface" = 'en7' ] || fail 'the active interface fallback selected the wrong device'
grep -F 'icon=1.0MB/s label=1.0MB/s' "$SKETCHYBAR_LOG" >/dev/null \
  || fail 'duplicate netstat rows were counted more than once'

printf 'SketchyBar network counter handling passed.\n'
