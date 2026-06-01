#!/usr/bin/env bash

set -euo pipefail

STATE_FILE="${HOME}/.config/yabai/float_state.json"
LABEL_PREFIX="float_persist_"

escape_regex() {
  printf '%s' "$1" | sed -E 's/[][(){}.^$*+?|\\-]/\\&/g'
}

[[ -f "$STATE_FILE" ]] || printf '[]\n' > "$STATE_FILE"
if ! jq empty "$STATE_FILE" >/dev/null 2>&1; then
  printf '[]\n' > "$STATE_FILE"
fi

rules_json="$(yabai -m rule --list 2>/dev/null || printf '[]\n')"

jq -r --arg prefix "$LABEL_PREFIX" '
  .[]
  | select(((.label // "") | startswith($prefix)))
  | (.index // empty)
' <<<"$rules_json" | sort -rn | while IFS= read -r rule_index; do
  [[ -n "$rule_index" ]] || continue
  yabai -m rule --remove "$rule_index" 2>/dev/null || true
done

jq -r '.[]' "$STATE_FILE" | while IFS= read -r app_name; do
  [[ -n "$app_name" ]] || continue
  app_regex="$(escape_regex "$app_name")"
  yabai -m rule --add app="^${app_regex}$" manage=off grid=6:6:1:1:4:4 label="${LABEL_PREFIX}${app_name}"
done
