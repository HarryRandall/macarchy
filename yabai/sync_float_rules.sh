#!/usr/bin/env bash

set -euo pipefail

YABAI_BIN="$(command -v "${YABAI_BIN:-yabai}" 2>/dev/null || true)"
JQ_BIN="$(command -v "${JQ_BIN:-jq}" 2>/dev/null || true)"
[ -n "$YABAI_BIN" ] && [ -n "$JQ_BIN" ] || exit 0

CONFIG_ROOT="${YABAI_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/yabai}"
STATE_FILE="$CONFIG_ROOT/float_state.json"
LABEL_PREFIX="float_persist_"

escape_regex() {
  printf '%s' "$1" | sed -E 's/[][(){}.^$*+?|\\-]/\\&/g'
}

mkdir -p "$CONFIG_ROOT"
[[ -f "$STATE_FILE" ]] || printf '[]\n' > "$STATE_FILE"
if ! "$JQ_BIN" -e 'type == "array" and all(.[]; type == "string")' "$STATE_FILE" >/dev/null 2>&1; then
  printf '[]\n' > "$STATE_FILE"
fi

rules_json="$("$YABAI_BIN" -m rule --list 2>/dev/null || printf '[]\n')"

"$JQ_BIN" -r --arg prefix "$LABEL_PREFIX" '
  .[]
  | select(((.label // "") | startswith($prefix)))
  | (.index // empty)
' <<<"$rules_json" | sort -rn | while IFS= read -r rule_index; do
  [[ -n "$rule_index" ]] || continue
  "$YABAI_BIN" -m rule --remove "$rule_index" 2>/dev/null || true
done

"$JQ_BIN" -r '.[]' "$STATE_FILE" | while IFS= read -r app_name; do
  [[ -n "$app_name" ]] || continue
  app_regex="$(escape_regex "$app_name")"
  "$YABAI_BIN" -m rule --add app="^${app_regex}$" manage=off label="${LABEL_PREFIX}${app_name}"
done
