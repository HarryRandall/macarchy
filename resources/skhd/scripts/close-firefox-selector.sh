#!/bin/bash
# Bundled with Macarchy for the default shortcuts. Closes Firefox's profile
# selector when Firefox is in front, which Command-W does not do on its own.
# It does nothing in other apps.
set -uo pipefail
command -v yabai >/dev/null && command -v jq >/dev/null || exit 0

windows="$(yabai -m query --windows 2>/dev/null)" || exit 0
# yabai reports focus itself, so this needs no Automation permission to ask
# System Events which app is in front.
selectors="$(jq -r '
  def firefox: ((.app // "") | ascii_downcase) == "firefox";
  if any(.[]; ."has-focus" == true and firefox) then
    .[]
    | select(firefox and .title == "Firefox - Choose a profile"
        and ."is-minimized" != true and ."is-hidden" != true)
    | .id
  else empty end' <<<"$windows" 2>/dev/null)"

while IFS= read -r window; do
  [ -n "$window" ] || continue
  yabai -m window "$window" --close >/dev/null 2>&1 || true
done <<<"$selectors"
