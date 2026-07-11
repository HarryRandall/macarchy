#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/macarchy-theme-test.XXXXXX")"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

export HOME="$TEST_ROOT/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"
export MACARCHY_THEMES_DIR="$REPO_ROOT/themes"

mkdir -p "$HOME"

# These modules only parse and validate data. None of the theme application
# modules are loaded by this test.
# shellcheck source=../lib/macarchy/common.sh
source "$REPO_ROOT/lib/macarchy/common.sh"
# shellcheck source=../lib/macarchy/theme.sh
source "$REPO_ROOT/lib/macarchy/theme.sh"
# shellcheck source=../lib/macarchy/colours.sh
source "$REPO_ROOT/lib/macarchy/colours.sh"

shopt -s nullglob
theme_files=("$MACARCHY_THEMES_DIR"/*/theme.env)
ghostty_files=("$MACARCHY_THEMES_DIR"/*/ghostty.conf)

[ "${#theme_files[@]}" -gt 0 ] || fail 'no theme.env files were found'
[ "${#ghostty_files[@]}" -eq "${#theme_files[@]}" ] || \
  fail 'each theme must have one Ghostty colour file'

for theme_file in "${theme_files[@]}"; do
  theme_dir="$(dirname "$theme_file")"
  theme_name="$(basename "$theme_dir")"

  macarchy_theme_load "$theme_name" || fail "invalid theme data: $theme_file"
  [ -z "$THEME_WALLPAPER" ] || [ -f "$theme_dir/$THEME_WALLPAPER" ] || \
    fail "missing wallpaper for $theme_name: $THEME_WALLPAPER"
done

for ghostty_file in "${ghostty_files[@]}"; do
  macarchy_ghostty_theme_valid "$ghostty_file" || \
    fail "invalid Ghostty colour data: $ghostty_file"
done

# Prove that theme.env remains data rather than executable shell code.
UNSAFE_THEMES="$TEST_ROOT/unsafe-themes"
mkdir -p "$UNSAFE_THEMES/untrusted"
printf '%s\n' 'DARK_MODE=$(touch "$TEST_ROOT/should-not-exist")' > "$UNSAFE_THEMES/untrusted/theme.env"
MACARCHY_THEMES_DIR="$UNSAFE_THEMES"
if macarchy_theme_load untrusted >/dev/null 2>&1; then
  fail 'an executable theme.env value passed validation'
fi
[ ! -e "$TEST_ROOT/should-not-exist" ] || fail 'theme.env content was executed'

printf 'Validated %d themes without applying them.\n' "${#theme_files[@]}"
