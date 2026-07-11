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
FAKE_BIN="$TEST_ROOT/fake-bin"
FAKE_BREW_LOG="$TEST_ROOT/brew.log"
FAKE_BREW_STATE="$TEST_ROOT/brew-state"

mkdir -p "$HOME" "$FAKE_BIN"
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

export HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME MACARCHY_BIN_HOME
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
TERMINAL_OUTPUT="$TEST_ROOT/terminal-install.out"
run_capture "$TERMINAL_OUTPUT" terminal
assert_file "$XDG_CONFIG_HOME/ghostty/config.ghostty"
cmp -s "$REPO_ROOT/ghostty/config.ghostty" "$XDG_CONFIG_HOME/ghostty/config.ghostty" || fail 'terminal config was not installed'
assert_no_path "$XDG_CONFIG_HOME/nvim"
assert_contains "$FAKE_BREW_LOG" 'install --cask ghostty'
assert_file "$XDG_STATE_HOME/macarchy/manifests/terminal.tsv"
BACKUP_COUNT_BEFORE="$(find "$XDG_STATE_HOME/macarchy/backups" -type f | wc -l | tr -d ' ')"
[ "$BACKUP_COUNT_BEFORE" -eq 1 ] || fail 'existing terminal config was not backed up once'
pass 'installs only the selected component and backs up existing files'

# Repeating an install should not make another backup or duplicate state.
run_capture "$TEST_ROOT/terminal-reinstall.out" install terminal
BACKUP_COUNT_AFTER="$(find "$XDG_STATE_HOME/macarchy/backups" -type f | wc -l | tr -d ' ')"
[ "$BACKUP_COUNT_AFTER" -eq "$BACKUP_COUNT_BEFORE" ] || fail 'idempotent install created another backup'
[ "$(wc -l < "$XDG_STATE_HOME/macarchy/manifests/terminal.tsv" | tr -d ' ')" -eq 1 ] || fail 'manifest contains duplicate entries'
pass 'repeated install is idempotent'

STATUS_OUTPUT="$TEST_ROOT/status.out"
run_capture "$STATUS_OUTPUT" status terminal
assert_contains "$STATUS_OUTPUT" 'installed (1 managed files)'
pass 'reports installed state'

# Uninstall restores the exact file that existed before Macarchy managed it.
run_capture "$TEST_ROOT/terminal-uninstall.out" uninstall terminal
assert_contains "$XDG_CONFIG_HOME/ghostty/config.ghostty" 'original ghostty config'
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
pass 'uses current window-manager formulae without starting services'

# SketchyBar's app labels rely on its companion ligature font.
: > "$FAKE_BREW_LOG"
run_capture "$TEST_ROOT/sketchybar.out" sketchybar
assert_contains "$FAKE_BREW_LOG" 'install FelixKratz/formulae/sketchybar'
assert_contains "$FAKE_BREW_LOG" 'install --cask font-sketchybar-app-font'
assert_file "$XDG_CONFIG_HOME/sketchybar/sketchybarrc"
pass 'installs the SketchyBar app font dependency'

# The shell bootstrap honours a non-default XDG config path, including spaces.
printf '%s\n' 'original zsh bootstrap' > "$HOME/.zshenv"
mv "$FAKE_BIN/brew" "$FAKE_BIN/brew.disabled"
run_capture "$TEST_ROOT/shell.out" shell
mv "$FAKE_BIN/brew.disabled" "$FAKE_BIN/brew"
assert_contains "$HOME/.zshenv" 'export ZDOTDIR="$XDG_CONFIG_HOME/zsh"'
assert_file "$XDG_CONFIG_HOME/zsh/.zshrc"
run_capture "$TEST_ROOT/shell-uninstall.out" uninstall shell
assert_contains "$HOME/.zshenv" 'original zsh bootstrap'
pass 'shell bootstrap uses portable XDG paths and restores cleanly'

if run_capture "$TEST_ROOT/unknown.out" install made-up-component; then
  fail 'unknown component unexpectedly succeeded'
fi
assert_contains "$TEST_ROOT/unknown.out" "unknown component 'made-up-component'"
pass 'rejects unknown components clearly'

printf 'All installer tests passed.\n'
