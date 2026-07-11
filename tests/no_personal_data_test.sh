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
