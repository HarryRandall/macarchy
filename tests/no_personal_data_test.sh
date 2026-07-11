#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

# Build the search terms in pieces so this test does not match its own source.
user_home_pattern='/'"Users"'/'
personal_name_pattern='(^|[^[:alnum:]_])[Hh]ar'"ry"'([^[:alnum:]_]|$)'
personal_bundle_pattern='com\.'"har"'ry([.]|$)'
search_pattern="$user_home_pattern|$personal_name_pattern|$personal_bundle_pattern"

set +e
matches="$(git -C "$REPO_ROOT" grep -nI -E "$search_pattern" -- .)"
status=$?
set -e

case "$status" in
  0)
    printf 'Personal hard-coded values found:\n%s\n' "$matches" >&2
    exit 1
    ;;
  1)
    printf 'No personal hard-coded paths or names found.\n'
    ;;
  *)
    printf 'git grep failed while checking for personal values.\n' >&2
    exit "$status"
    ;;
esac

while IFS= read -r -d '' relative; do
  path="$REPO_ROOT/$relative"
  [ -f "$path" ] || continue
  LC_ALL=C grep -Iq . "$path" && continue

  set +e
  binary_matches="$(strings "$path" | grep -E -i "$search_pattern|Shutterstock|No use without permission")"
  status=$?
  set -e
  if [ "$status" -eq 0 ]; then
    printf 'Personal or restricted metadata found in %s:\n%s\n' "$relative" "$binary_matches" >&2
    exit 1
  fi
  [ "$status" -eq 1 ] || exit "$status"
done < <(git -C "$REPO_ROOT" ls-files -z)

printf 'No personal or restricted binary metadata found.\n'
