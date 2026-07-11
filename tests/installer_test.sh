#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
INSTALLER="$REPO_ROOT/install"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/macarchy-installer-test.XXXXXX")"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

pass() {
  printf 'ok - %s\n' "$1"
}

assert_file() {
  [ -f "$1" ] || fail "expected file: $1"
}

assert_no_path() {
  [ ! -e "$1" ] && [ ! -L "$1" ] || fail "expected no path: $1"
}

assert_contains() {
  local file="$1" expected="$2"
  grep -F -- "$expected" "$file" >/dev/null || fail "expected '$expected' in $file"
}

HOME="$TEST_ROOT/Home With Spaces"
XDG_CONFIG_HOME="$HOME/Custom Config"
XDG_DATA_HOME="$HOME/Custom Data"
XDG_STATE_HOME="$HOME/Custom State"
MACARCHY_BIN_HOME="$HOME/Custom Bin"
MACARCHY_APPLICATIONS_DIR="$TEST_ROOT/Applications"
FAKE_BIN="$TEST_ROOT/fake-bin"
FAKE_BREW_LOG="$TEST_ROOT/brew.log"
FAKE_BREW_STATE="$TEST_ROOT/brew-state"

mkdir -p "$HOME" "$FAKE_BIN" "$MACARCHY_APPLICATIONS_DIR"
: > "$FAKE_BREW_LOG"
: > "$FAKE_BREW_STATE"

cat > "$FAKE_BIN/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$FAKE_BREW_LOG"

case "${1:-}" in
  list)
    kind="${2:-}"
    item="${4:-${3:-}}"
    grep -Fqx "$kind:$item" "$FAKE_BREW_STATE"
    ;;
  install)
    if [ "${2:-}" = '--cask' ]; then
      printf '%s\n' "--cask:${3}" >> "$FAKE_BREW_STATE"
    else
      item="${2##*/}"
      printf '%s\n' "--formula:$item" >> "$FAKE_BREW_STATE"
    fi
    ;;
  --prefix)
    printf '%s\n' "$TEST_ROOT/fake-homebrew"
    ;;
  *)
    printf 'unexpected fake brew arguments: %s\n' "$*" >&2
    exit 2
    ;;
esac
EOF
chmod +x "$FAKE_BIN/brew"

export HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME MACARCHY_BIN_HOME MACARCHY_APPLICATIONS_DIR
export FAKE_BREW_LOG FAKE_BREW_STATE TEST_ROOT
export PATH="$FAKE_BIN:/usr/bin:/bin:/usr/sbin:/sbin"

run_capture() {
  local output="$1"
  shift
  "$INSTALLER" "$@" > "$output" 2>&1
}

# Listing is read-only and documents every selectable component.
LIST_OUTPUT="$TEST_ROOT/list.out"
run_capture "$LIST_OUTPUT" --list
assert_contains "$LIST_OUTPUT" 'window-manager'
assert_contains "$LIST_OUTPUT" 'raycast'
pass 'lists modular components'

# A dry run must not call Homebrew or write to the temporary home.
DRY_OUTPUT="$TEST_ROOT/dry-run.out"
run_capture "$DRY_OUTPUT" --dry-run install window-manager
assert_no_path "$XDG_CONFIG_HOME/yabai"
[ ! -s "$FAKE_BREW_LOG" ] || fail 'dry run called Homebrew'
assert_contains "$DRY_OUTPUT" 'Would ensure Homebrew formula: asmvik/formulae/yabai'
pass 'dry run is side-effect free'

# Direct shorthand installs one component and leaves unrelated components alone.
mkdir -p "$XDG_CONFIG_HOME/ghostty"
printf '%s\n' 'original ghostty config' > "$XDG_CONFIG_HOME/ghostty/config.ghostty"
printf '%s\n' 'original legacy ghostty config' > "$XDG_CONFIG_HOME/ghostty/config"
TERMINAL_OUTPUT="$TEST_ROOT/terminal-install.out"
run_capture "$TERMINAL_OUTPUT" terminal
assert_file "$XDG_CONFIG_HOME/ghostty/config.ghostty"
cmp -s "$REPO_ROOT/ghostty/config.ghostty" "$XDG_CONFIG_HOME/ghostty/config.ghostty" || fail 'terminal config was not installed'
assert_contains "$XDG_CONFIG_HOME/ghostty/config" 'Legacy Ghostty compatibility file'
assert_no_path "$XDG_CONFIG_HOME/nvim"
assert_contains "$FAKE_BREW_LOG" 'install --cask ghostty'
assert_file "$XDG_STATE_HOME/macarchy/manifests/terminal.tsv"
BACKUP_COUNT_BEFORE="$(find "$XDG_STATE_HOME/macarchy/backups" -type f | wc -l | tr -d ' ')"
[ "$BACKUP_COUNT_BEFORE" -eq 2 ] || fail 'current and legacy terminal configs were not backed up once'
pass 'installs only the selected component and backs up existing files'

# Repeating an install should not make another backup or duplicate state.
run_capture "$TEST_ROOT/terminal-reinstall.out" install terminal
BACKUP_COUNT_AFTER="$(find "$XDG_STATE_HOME/macarchy/backups" -type f | wc -l | tr -d ' ')"
[ "$BACKUP_COUNT_AFTER" -eq "$BACKUP_COUNT_BEFORE" ] || fail 'idempotent install created another backup'
[ "$(wc -l < "$XDG_STATE_HOME/macarchy/manifests/terminal.tsv" | tr -d ' ')" -eq 2 ] || fail 'manifest contains duplicate entries'
pass 'repeated install is idempotent'

# A rerun must stop rather than overwrite a locally edited managed file.
printf '%s\n' 'local terminal edit' > "$XDG_CONFIG_HOME/ghostty/config.ghostty"
if run_capture "$TEST_ROOT/terminal-conflict.out" install terminal; then
  fail 'update overwrote a locally edited managed file without --force'
fi
assert_contains "$XDG_CONFIG_HOME/ghostty/config.ghostty" 'local terminal edit'
assert_contains "$TEST_ROOT/terminal-conflict.out" 'managed file has local edits'

run_capture "$TEST_ROOT/terminal-force.out" --force install terminal
cmp -s "$REPO_ROOT/ghostty/config.ghostty" "$XDG_CONFIG_HOME/ghostty/config.ghostty" \
  || fail 'forced update did not replace the managed file'
BACKUP_COUNT_FORCED="$(find "$XDG_STATE_HOME/macarchy/backups" -type f | wc -l | tr -d ' ')"
[ "$BACKUP_COUNT_FORCED" -eq $((BACKUP_COUNT_BEFORE + 1)) ] \
  || fail 'forced update did not preserve the locally edited version'
pass 'updates stop on local edits unless force is explicit'

# Files removed from a later component version are pruned when they are still
# unchanged. This keeps updates from leaving obsolete generated bundles behind.
OLD_MANAGED="$XDG_CONFIG_HOME/ghostty/old-managed.conf"
printf '%s\n' 'obsolete managed file' > "$OLD_MANAGED"
OLD_HASH="$(shasum -a 256 "$OLD_MANAGED" | awk '{print $1}')"
printf '%s\t-\t%s\n' "$OLD_MANAGED" "$OLD_HASH" >> "$XDG_STATE_HOME/macarchy/manifests/terminal.tsv"
run_capture "$TEST_ROOT/terminal-prune.out" install terminal
assert_no_path "$OLD_MANAGED"
if grep -F -- "$OLD_MANAGED" "$XDG_STATE_HOME/macarchy/manifests/terminal.tsv" >/dev/null; then
  fail 'obsolete managed file remained in the manifest'
fi
pass 'updates prune unchanged files no longer shipped by a component'

STATUS_OUTPUT="$TEST_ROOT/status.out"
run_capture "$STATUS_OUTPUT" status terminal
assert_contains "$STATUS_OUTPUT" 'installed (2 managed files)'
pass 'reports installed state'

# Uninstall restores the exact file that existed before Macarchy managed it.
run_capture "$TEST_ROOT/terminal-uninstall.out" uninstall terminal
assert_contains "$XDG_CONFIG_HOME/ghostty/config.ghostty" 'original ghostty config'
assert_contains "$XDG_CONFIG_HOME/ghostty/config" 'original legacy ghostty config'
assert_no_path "$XDG_STATE_HOME/macarchy/manifests/terminal.tsv"
pass 'uninstall restores the original file'

# A file created by Macarchy is removed, but a later user edit is never deleted.
run_capture "$TEST_ROOT/nvim-install.out" nvim
assert_file "$XDG_CONFIG_HOME/nvim/init.lua"
printf '%s\n' '-- user edit' > "$XDG_CONFIG_HOME/nvim/init.lua"
if run_capture "$TEST_ROOT/nvim-uninstall.out" uninstall nvim; then
  fail 'partial uninstall should report modified files'
fi
assert_contains "$XDG_CONFIG_HOME/nvim/init.lua" '-- user edit'
assert_contains "$TEST_ROOT/nvim-uninstall.out" 'kept modified file'
assert_file "$XDG_STATE_HOME/macarchy/manifests/nvim.tsv"
pass 'uninstall preserves modified files and keeps their manifest entries'

# Window manager dependencies use the maintained taps and no service is started.
: > "$FAKE_BREW_LOG"
run_capture "$TEST_ROOT/window-manager.out" window-manager
assert_contains "$FAKE_BREW_LOG" 'install asmvik/formulae/yabai'
assert_contains "$FAKE_BREW_LOG" 'install asmvik/formulae/skhd'
assert_contains "$FAKE_BREW_LOG" 'install FelixKratz/formulae/borders'
if grep -E 'services|launchctl|sudo' "$FAKE_BREW_LOG" >/dev/null; then
  fail 'installer attempted to start a service or elevate privileges'
fi
assert_file "$XDG_CONFIG_HOME/yabai/yabairc"
assert_file "$XDG_CONFIG_HOME/skhd/skhdrc"
assert_file "$XDG_CONFIG_HOME/skhd/local.skhdrc"
if grep -F "$XDG_CONFIG_HOME/skhd/local.skhdrc" "$XDG_STATE_HOME/macarchy/manifests/window-manager.tsv" >/dev/null; then
  fail 'machine-specific skhd shortcuts were added to the managed manifest'
fi
assert_contains "$TEST_ROOT/window-manager.out" 'launchctl setenv XDG_CONFIG_HOME'
pass 'uses current window-manager formulae without starting services'

# SketchyBar's app labels rely on its companion ligature font.
: > "$FAKE_BREW_LOG"
run_capture "$TEST_ROOT/sketchybar.out" sketchybar
assert_contains "$FAKE_BREW_LOG" 'install FelixKratz/formulae/sketchybar'
if [ "$(uname -s)" = 'Darwin' ] && [ "$(uname -m)" = 'arm64' ]; then
  assert_contains "$FAKE_BREW_LOG" 'install macmon'
fi
assert_contains "$FAKE_BREW_LOG" 'install --cask font-sketchybar-app-font'
assert_file "$XDG_CONFIG_HOME/sketchybar/sketchybarrc"
pass 'installs the SketchyBar app font dependency'

# Themes include their shared library but start without mutable runtime state.
mkdir -p "$XDG_CONFIG_HOME/themes/lumon/backgrounds" "$XDG_CONFIG_HOME/themes/blackgold/backgrounds"
printf '%s\n' 'DARK_MODE=true' > "$XDG_CONFIG_HOME/themes/lumon/theme.env"
printf '%s\n' 'old wallpaper' > "$XDG_CONFIG_HOME/themes/lumon/backgrounds/old.jpg"
printf '%s\n' 'old wallpaper' > "$XDG_CONFIG_HOME/themes/blackgold/backgrounds/old.jpg"
run_capture "$TEST_ROOT/themes.out" themes
assert_file "$XDG_CONFIG_HOME/themes/blackgold/theme.env"
assert_file "$XDG_DATA_HOME/macarchy/lib/theme.sh"
assert_file "$MACARCHY_BIN_HOME/theme-switch"
assert_no_path "$XDG_CONFIG_HOME/themes/.current"
assert_no_path "$XDG_CONFIG_HOME/themes/lumon"
assert_no_path "$XDG_CONFIG_HOME/themes/blackgold/backgrounds"
find "$XDG_STATE_HOME/macarchy/backups" -path '*themes/*legacy-lumon' -type d | grep . >/dev/null \
  || fail 'legacy renamed theme was not backed up'
find "$XDG_STATE_HOME/macarchy/backups" -path '*themes/*legacy-blackgold-backgrounds' -type d | grep . >/dev/null \
  || fail 'legacy wallpaper directory was not backed up'
assert_contains "$TEST_ROOT/themes.out" "$MACARCHY_BIN_HOME/theme-switch"
if grep -F 'desktoppr' "$TEST_ROOT/themes.out" "$FAKE_BREW_LOG" >/dev/null; then
  fail 'themes installed optional desktoppr despite having a system fallback'
fi
pass 'installs theme code separately from runtime state'

# Uninstall removes only unchanged runtime files recorded by theme-switch.
THEME_RUNTIME="$XDG_STATE_HOME/macarchy/themes/current"
THEME_SHELL_STATE="$XDG_CONFIG_HOME/macarchy/generated/shell-env"
THEME_GENERATED_MANIFEST="$XDG_STATE_HOME/macarchy/generated/themes.tsv"
mkdir -p "$(dirname "$THEME_RUNTIME")" "$(dirname "$THEME_SHELL_STATE")" \
  "$(dirname "$THEME_GENERATED_MANIFEST")"
printf '%s\n' 'carbonfox' > "$THEME_RUNTIME"
printf '%s\n' 'generated shell state' > "$THEME_SHELL_STATE"
RUNTIME_HASH="$(shasum -a 256 "$THEME_RUNTIME" | awk '{print $1}')"
SHELL_STATE_HASH="$(shasum -a 256 "$THEME_SHELL_STATE" | awk '{print $1}')"
printf '%s\t%s\n%s\t%s\n' \
  "$THEME_RUNTIME" "$RUNTIME_HASH" \
  "$THEME_SHELL_STATE" "$SHELL_STATE_HASH" > "$THEME_GENERATED_MANIFEST"
printf '%s\n' 'locally edited shell state' > "$THEME_SHELL_STATE"

if run_capture "$TEST_ROOT/themes-uninstall.out" uninstall themes; then
  fail 'themes uninstall did not report a modified generated file'
fi
assert_no_path "$THEME_RUNTIME"
assert_contains "$THEME_SHELL_STATE" 'locally edited shell state'
assert_contains "$THEME_GENERATED_MANIFEST" "$THEME_SHELL_STATE"
assert_no_path "$XDG_STATE_HOME/macarchy/manifests/themes.tsv"
rm -f "$THEME_SHELL_STATE"
run_capture "$TEST_ROOT/themes-uninstall-finish.out" uninstall themes
assert_no_path "$THEME_GENERATED_MANIFEST"
pass 'theme uninstall removes generated state but preserves local edits'

# Existing applications and a suitable Node runtime satisfy Raycast's
# dependencies even when Homebrew did not install them.
mkdir -p "$MACARCHY_APPLICATIONS_DIR/Raycast.app"
cat > "$FAKE_BIN/node" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$FAKE_BIN/node"
: > "$FAKE_BREW_LOG"
run_capture "$TEST_ROOT/raycast.out" raycast
assert_file "$XDG_CONFIG_HOME/raycast/extensions/macarchy-theme-switcher/package.json"
if grep -F 'install --cask raycast' "$FAKE_BREW_LOG" >/dev/null; then
  fail 'installer tried to replace an existing Raycast application'
fi
if grep -F 'install node' "$FAKE_BREW_LOG" >/dev/null; then
  fail 'installer ignored a suitable existing Node runtime'
fi
pass 'accepts existing applications and Node runtimes'

# The shell bootstrap honours a non-default XDG config path, including spaces.
printf '%s\n' 'original zsh bootstrap' > "$HOME/.zshenv"
printf '%s\n' 'existing root zshrc' > "$HOME/.zshrc"
printf '%s\n' 'existing root zprofile' > "$HOME/.zprofile"
mv "$FAKE_BIN/brew" "$FAKE_BIN/brew.disabled"
run_capture "$TEST_ROOT/shell.out" shell
mv "$FAKE_BIN/brew.disabled" "$FAKE_BIN/brew"
assert_contains "$HOME/.zshenv" 'export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-'
assert_contains "$HOME/.zshenv" 'Custom\ Config}'
assert_contains "$HOME/.zshenv" 'export ZDOTDIR="${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}"'
assert_contains "$TEST_ROOT/shell.out" 'sets ZDOTDIR'
[ "$(env -i HOME="$HOME" PATH=/usr/bin:/bin zsh -c 'source "$HOME/.zshenv"; print -r -- "$XDG_CONFIG_HOME"')" = "$XDG_CONFIG_HOME" ] \
  || fail 'shell bootstrap did not restore the custom XDG path'
assert_file "$XDG_CONFIG_HOME/zsh/.zshrc"
run_capture "$TEST_ROOT/shell-uninstall.out" uninstall shell
assert_contains "$HOME/.zshenv" 'original zsh bootstrap'
pass 'shell bootstrap uses portable XDG paths and restores cleanly'

if run_capture "$TEST_ROOT/force-status.out" --force status terminal; then
  fail '--force unexpectedly worked with status'
fi
assert_contains "$TEST_ROOT/force-status.out" '--force can only be used while installing components'
pass 'limits force to explicit installs'

if run_capture "$TEST_ROOT/unknown.out" install made-up-component; then
  fail 'unknown component unexpectedly succeeded'
fi
assert_contains "$TEST_ROOT/unknown.out" "unknown component 'made-up-component'"
pass 'rejects unknown components clearly'

printf 'All installer tests passed.\n'
