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
# shellcheck source=../lib/macarchy/apply/tools.sh
source "$REPO_ROOT/lib/macarchy/apply/tools.sh"
# shellcheck source=../lib/macarchy/apply/desktop.sh
source "$REPO_ROOT/lib/macarchy/apply/desktop.sh"

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

# Runtime state belongs outside a theme pack so separately cloned or read-only
# packs are not modified when a theme is selected.
[ "$MACARCHY_THEME_STATE" = "$XDG_STATE_HOME/macarchy/themes/current" ] || \
  fail 'active theme state is stored inside the theme pack'
[ "$MACARCHY_BACKGROUND_STATE" = "$XDG_STATE_HOME/macarchy/themes/backgrounds.json" ] || \
  fail 'background state is stored inside the theme pack'

# A damaged preferences file must be preserved for inspection rather than
# replaced with empty output from a failed jq command.
RUNTIME_THEMES="$TEST_ROOT/runtime-themes"
mkdir -p "$RUNTIME_THEMES/demo" "$(dirname "$MACARCHY_BACKGROUND_STATE")"
: > "$RUNTIME_THEMES/demo/wallpaper.jpg"
MACARCHY_THEME_NAME=demo
MACARCHY_THEME_DIR="$RUNTIME_THEMES/demo"
MACARCHY_LEGACY_THEME_STATE="$RUNTIME_THEMES/.current"
MACARCHY_LEGACY_BACKGROUND_STATE="$RUNTIME_THEMES/.backgrounds.json"
printf '%s\n' demo > "$MACARCHY_LEGACY_THEME_STATE"
[ "$(macarchy_theme_current)" = demo ] || fail 'legacy active theme state was not read'
printf '%s\n' lumon > "$MACARCHY_LEGACY_THEME_STATE"
[ "$(macarchy_theme_current)" = cool-blue ] || fail 'renamed Lumon state was not mapped to Cool Blue'

printf '%s\n' '{"other":"kept.jpg"}' > "$MACARCHY_LEGACY_BACKGROUND_STATE"
macarchy_theme_save_background wallpaper.jpg || fail 'legacy background state was not migrated'
[ "$(jq -r '.other' "$MACARCHY_BACKGROUND_STATE")" = 'kept.jpg' ] || \
  fail 'legacy background choices were lost during migration'

printf '%s\n' 'not valid json' > "$MACARCHY_BACKGROUND_STATE"
cp "$MACARCHY_BACKGROUND_STATE" "$TEST_ROOT/backgrounds.before"
if macarchy_theme_save_background wallpaper.jpg >/dev/null 2>&1; then
  fail 'invalid background state was accepted'
fi
cmp -s "$TEST_ROOT/backgrounds.before" "$MACARCHY_BACKGROUND_STATE" || \
  fail 'invalid background state was overwritten'

printf '%s\n' '{}' > "$MACARCHY_BACKGROUND_STATE"
macarchy_theme_save_background wallpaper.jpg || fail 'valid background state was not updated'
[ "$(jq -r '.demo' "$MACARCHY_BACKGROUND_STATE")" = 'wallpaper.jpg' ] || \
  fail 'background selection was not saved'
printf '%s\n' demo | macarchy_write_generated "$MACARCHY_THEME_STATE" || \
  fail 'active theme state was not recorded'

# Generated integration files are checksummed for safe installer cleanup. The
# btop adapter must never rewrite the user's main btop configuration.
THEME_DARK_MODE=true
THEME_BORDER_ACTIVE=0x80ed9a1d
THEME_BORDER_INACTIVE=0x00000000
THEME_BORDER_WIDTH=6.0
THEME_SKETCHYBAR_BAR_COLOR=0x00000000
THEME_SKETCHYBAR_TEXT_COLOR=0xffffffff
THEME_NVIM_COLORSCHEME=gruvbox
MACARCHY_THEME_DIR="$REPO_ROOT/themes/amber-metal"

macarchy_apply_shell >/dev/null || fail 'shell theme state could not be generated'
[ -f "$MACARCHY_GENERATED_DIR/shell-env" ] || fail 'shell state was not written under generated config'
[ ! -e "$MACARCHY_THEMES_DIR/.shell-env" ] || fail 'shell state polluted the theme pack'
grep -F "MACARCHY_ACCENT='#ed9a1d'" "$MACARCHY_GENERATED_DIR/shell-env" >/dev/null || \
  fail 'shell accent did not discard the border alpha channel'

mkdir -p "$XDG_CONFIG_HOME/btop"
printf '%s\n' 'color_theme = "my-own-theme"' 'update_ms = 5000' > "$XDG_CONFIG_HOME/btop/btop.conf"
cp "$XDG_CONFIG_HOME/btop/btop.conf" "$TEST_ROOT/btop.before"
pkill() { return 1; }
macarchy_apply_btop >/dev/null || fail 'btop theme could not be generated'
cmp -s "$TEST_ROOT/btop.before" "$XDG_CONFIG_HOME/btop/btop.conf" || \
  fail 'theme application rewrote btop.conf'
[ -f "$XDG_CONFIG_HOME/btop/themes/macarchy.theme" ] || fail 'generated btop theme is missing'

while IFS=$'\t' read -r generated checksum; do
  [ -f "$generated" ] || fail "manifest points at a missing generated file: $generated"
  [ "$(macarchy_file_hash "$generated")" = "$checksum" ] || \
    fail "manifest checksum does not match: $generated"
done < "$MACARCHY_GENERATED_MANIFEST"
grep -F "$MACARCHY_BACKGROUND_STATE" "$MACARCHY_GENERATED_MANIFEST" >/dev/null || \
  fail 'background state is absent from the generated-file manifest'
grep -F "$MACARCHY_GENERATED_DIR/shell-env" "$MACARCHY_GENERATED_MANIFEST" >/dev/null || \
  fail 'shell state is absent from the generated-file manifest'
grep -F "$XDG_CONFIG_HOME/btop/themes/macarchy.theme" "$MACARCHY_GENERATED_MANIFEST" >/dev/null || \
  fail 'btop theme is absent from the generated-file manifest'

if printf '%s\n' 'content' | macarchy_atomic_write /dev/null/macarchy-test >/dev/null 2>&1; then
  fail 'an impossible atomic write reported success'
fi

ORIGINAL_GENERATED_DIR="$MACARCHY_GENERATED_DIR"
MACARCHY_GENERATED_DIR=/dev/null/macarchy-generated
if macarchy_apply_shell >/dev/null 2>&1; then
  fail 'theme adapter reported success after its generated write failed'
fi
MACARCHY_GENERATED_DIR="$ORIGINAL_GENERATED_DIR"

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
