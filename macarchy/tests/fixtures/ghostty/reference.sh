#!/bin/bash
# The exact pipeline from theme-switch, extracted verbatim so the Swift port can
# be diffed against it rather than assumed equivalent.
# usage: reference.sh <ghostty-config> <theme-ghostty-conf> <theme-name>
set -uo pipefail
GHOSTTY_CONFIG="$1"; THEME_CONF="$2"; THEME="$3"
TMP=$(mktemp)
awk '
    /^# --- THEME COLORS / { exit }
    NF {
        for (i = 0; i < blanks; i++) print ""
        blanks = 0
        print
        next
    }
    { blanks++ }
' "$GHOSTTY_CONFIG" \
    | grep -Ev "^[[:space:]]*(background|foreground|cursor-color|cursor-text|selection-background|selection-foreground|palette|theme)[[:space:]]*=" \
    | grep -Ev "^[[:space:]]*config-file[[:space:]]*=.*\.themes/" \
    > "$TMP" || true
echo "" >> "$TMP"
echo "# --- THEME COLORS ($THEME) ---" >> "$TMP"
cat "$THEME_CONF" >> "$TMP"
cat "$TMP"; rm -f "$TMP"
