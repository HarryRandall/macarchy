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
# shellcheck source=../lib/macarchy/apply/raycast.sh
source "$REPO_ROOT/lib/macarchy/apply/raycast.sh"
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

# Locally preserved copies of the original eight packs remain valid and keep
# their original names. These small fixtures exercise their data format without
# requiring the old wallpaper assets in the public repository.
LEGACY_THEMES="$TEST_ROOT/legacy-themes"
write_legacy_theme() {
  local name="$1"
  local foreground="$2"
  local accent="${3:-}"
  local accent_index="${4:-4}"
  shift 4

  mkdir -p "$LEGACY_THEMES/$name"
  printf '%s\n' \
    'DARK_MODE=true' \
    'WALLPAPER=""' \
    'NVIM_COLORSCHEME="legacy"' \
    'BORDER_ACTIVE="0xff112233"' \
    'BORDER_INACTIVE="0x00000000"' \
    'BORDER_WIDTH="6.0"' > "$LEGACY_THEMES/$name/theme.env"
  if [ -n "$accent" ]; then
    printf 'FIREFOX_ACCENT="%s"\n' "$accent" >> "$LEGACY_THEMES/$name/theme.env"
  fi
  printf '%s\n' \
    'background = #101010' \
    "foreground = $foreground" \
    'palette = 0=#101010' \
    'palette = 4=#445566' \
    "palette = $accent_index=${accent:-#112233}" > "$LEGACY_THEMES/$name/ghostty.conf"
  if [ "$#" -gt 0 ]; then
    printf '%s\n' "$@" >> "$LEGACY_THEMES/$name/ghostty.conf"
  fi
}

write_legacy_theme awakening '#dacbe6' '#ffff00' 2 'background-opacity = 0.85'
write_legacy_theme blackgold '#ebdbb2' '#bfa75d' 5
write_legacy_theme carbonfox '#f2f4f8' '#78a9ff' 4
write_legacy_theme city-783 '#b9bec6' '#eceff2' 15 'background-opacity = 0.85'
write_legacy_theme lumon '#d6e2ee' '' 12
write_legacy_theme matte-black '#bebebe' '' 4
write_legacy_theme midnight '#F0F6FF' '#66CCFF' 6 \
  'window-padding-y = 8,8' \
  'window-padding-x = 8,8' \
  'window-padding-balance = true'
write_legacy_theme turbonite '#eae9e3' '#ed9a1d' 11

MACARCHY_THEMES_DIR="$LEGACY_THEMES"
expected_legacy_themes=$'awakening\nblackgold\ncarbonfox\ncity-783\nlumon\nmatte-black\nmidnight\nturbonite'
[ "$(macarchy_theme_list)" = "$expected_legacy_themes" ] || \
  fail 'legacy theme names changed while listing them'
for theme_name in awakening blackgold carbonfox city-783 lumon matte-black midnight turbonite; do
  macarchy_theme_load "$theme_name" || fail "legacy theme format was rejected: $theme_name"
  macarchy_ghostty_theme_valid "$LEGACY_THEMES/$theme_name/ghostty.conf" || \
    fail "legacy Ghostty settings were rejected: $theme_name"
done
mkdir -p "$(dirname "$MACARCHY_THEME_STATE")"
printf '%s\n' lumon > "$MACARCHY_THEME_STATE"
[ "$(macarchy_theme_cycle next)" = matte-black ] || fail 'theme cycling renamed an installed Lumon pack'
printf '%s\n' turbonite > "$MACARCHY_THEME_STATE"
[ "$(macarchy_theme_cycle next)" = awakening ] || fail 'theme cycling renamed an installed Turbonite pack'
rm -f "$MACARCHY_THEME_STATE"

INVALID_GHOSTTY="$TEST_ROOT/invalid-ghostty.conf"
for invalid_setting in \
  'background-opacity = 1.1' \
  'window-padding-x = -1' \
  'window-padding-y = 8,unsafe' \
  'window-padding-balance = yes' \
  'font-family = unexpected'; do
  printf '%s\n' 'background = #101010' "$invalid_setting" > "$INVALID_GHOSTTY"
  if macarchy_ghostty_theme_valid "$INVALID_GHOSTTY"; then
    fail "unsafe Ghostty value was accepted: $invalid_setting"
  fi
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
mkdir -p "$RUNTIME_THEMES/demo" "$RUNTIME_THEMES/cool-blue" "$(dirname "$MACARCHY_BACKGROUND_STATE")"
: > "$RUNTIME_THEMES/demo/wallpaper.jpg"
MACARCHY_THEMES_DIR="$RUNTIME_THEMES"
MACARCHY_THEME_NAME=demo
MACARCHY_THEME_DIR="$RUNTIME_THEMES/demo"
MACARCHY_LEGACY_THEME_STATE="$RUNTIME_THEMES/.current"
MACARCHY_LEGACY_BACKGROUND_STATE="$RUNTIME_THEMES/.backgrounds.json"
printf '%s\n' demo > "$MACARCHY_LEGACY_THEME_STATE"
[ "$(macarchy_theme_current)" = demo ] || fail 'legacy active theme state was not read'
printf '%s\n' lumon > "$MACARCHY_LEGACY_THEME_STATE"
[ "$(macarchy_theme_current)" = cool-blue ] || fail 'renamed Lumon state was not mapped to Cool Blue'
mkdir -p "$RUNTIME_THEMES/lumon"
[ "$(macarchy_theme_current)" = lumon ] || fail 'an installed Lumon pack was renamed to Cool Blue'

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
MACARCHY_THEMES_DIR="$LEGACY_THEMES"
macarchy_theme_load awakening || fail 'Awakening fixture could not be loaded for adapter tests'

macarchy_apply_shell >/dev/null || fail 'shell theme state could not be generated'
[ -f "$MACARCHY_GENERATED_DIR/shell-env" ] || fail 'shell state was not written under generated config'
[ ! -e "$MACARCHY_THEMES_DIR/.shell-env" ] || fail 'shell state polluted the theme pack'
grep -F "MACARCHY_ACCENT_IDX='2'" "$MACARCHY_GENERATED_DIR/shell-env" >/dev/null || \
  fail 'legacy FIREFOX_ACCENT did not select its Ghostty palette index'
grep -F "MACARCHY_ACCENT='#ffff00'" "$MACARCHY_GENERATED_DIR/shell-env" >/dev/null || \
  fail 'legacy FIREFOX_ACCENT was not preserved in shell state'

mkdir -p "$XDG_CONFIG_HOME/sketchybar"
sketchybar() { :; }
macarchy_apply_sketchybar >/dev/null || fail 'SketchyBar theme state could not be generated'
unset -f sketchybar
grep -F 'TEXT_COLOR="0xffdacbe6"' "$XDG_CONFIG_HOME/sketchybar/theme.sh" >/dev/null || \
  fail 'SketchyBar text was not derived from the Ghostty foreground'

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
grep -F "$XDG_CONFIG_HOME/sketchybar/theme.sh" "$MACARCHY_GENERATED_MANIFEST" >/dev/null || \
  fail 'SketchyBar theme state is absent from the generated-file manifest'
grep -F "$XDG_CONFIG_HOME/btop/themes/macarchy.theme" "$MACARCHY_GENERATED_MANIFEST" >/dev/null || \
  fail 'btop theme is absent from the generated-file manifest'

# Raycast follows the selected appearance while retaining sensible defaults for
# both modes. A stub keeps this test away from the machine's real preferences.
RAYCAST_DEFAULTS_LOG="$TEST_ROOT/raycast-defaults.log"
export RAYCAST_DEFAULTS_LOG
MACARCHY_DEFAULTS_BIN="$TEST_ROOT/defaults"
MACARCHY_RAYCAST_APP="$TEST_ROOT/Raycast.app"
export MACARCHY_DEFAULTS_BIN MACARCHY_RAYCAST_APP
mkdir -p "$MACARCHY_RAYCAST_APP"
printf '%s\n' '#!/bin/sh' 'printf "%s\n" "$*" >> "$RAYCAST_DEFAULTS_LOG"' > "$MACARCHY_DEFAULTS_BIN"
chmod +x "$MACARCHY_DEFAULTS_BIN"
uname() { printf 'Darwin\n'; }
macarchy_apply_raycast >/dev/null || fail 'Raycast appearance defaults could not be generated'
unset -f uname
grep -F 'write com.raycast.macos raycastCurrentThemeId -string bundled-raycast-dark' "$RAYCAST_DEFAULTS_LOG" >/dev/null || \
  fail 'Raycast current theme did not follow dark mode'
grep -F 'write com.raycast.macos raycastCurrentThemeIdDarkAppearance -string bundled-raycast-dark' "$RAYCAST_DEFAULTS_LOG" >/dev/null || \
  fail 'Raycast dark default was not restored'
grep -F 'write com.raycast.macos raycastCurrentThemeIdLightAppearance -string bundled-raycast-light' "$RAYCAST_DEFAULTS_LOG" >/dev/null || \
  fail 'Raycast light default was not restored'
unset MACARCHY_DEFAULTS_BIN MACARCHY_RAYCAST_APP RAYCAST_DEFAULTS_LOG

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

printf '%s\n' 'DARK_MODE=true' 'FIREFOX_ACCENT=blue' > "$UNSAFE_THEMES/untrusted/theme.env"
if macarchy_theme_load untrusted >/dev/null 2>&1; then
  fail 'an invalid FIREFOX_ACCENT passed validation'
fi

printf 'Validated %d themes without applying them.\n' "${#theme_files[@]}"
