#!/bin/bash
# Runs setup and uninstall against a temporary home with fake daemons, never
# the installed desktop. Usage: tests/integration/setup.sh
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
swift build --package-path "$REPO" -c debug >/dev/null
CLI="$(swift build --package-path "$REPO" --show-bin-path)/macarchy"

HOME_DIR="$(mktemp -d -t macarchy-setup-test)"
RESOURCES="$(mktemp -d -t macarchy-setup-resources)"
trap 'rm -rf "$HOME_DIR" "$RESOURCES"' EXIT
# The repository splits bundled files by kind; stage them in the app bundle's
# Resources layout, which is what Paths.resources expects.
cp "$REPO/resources/app/logo.svg" "$RESOURCES/"
cp -R "$REPO/resources/themes" "$REPO/resources/integrations/sketchybar" \
  "$REPO/resources/integrations/skhd" "$RESOURCES/"
export MACARCHY_HOME="$HOME_DIR" MACARCHY_RESOURCES="$RESOURCES"
export MACARCHY_SEARCH_PATH="$HOME_DIR/fake-bin" MACARCHY_APPLICATIONS="$HOME_DIR/Applications"
mkdir -p "$MACARCHY_SEARCH_PATH" "$HOME_DIR/.config/yabai" "$HOME_DIR/.config/skhd"
# Each fake records its calls. brew is there because uninstall restarts the
# services, and SketchyBar and borders start through Homebrew. There is no
# fake launchctl, so launchd jobs resolve to a missing file and are never reached.
CALLS="$HOME_DIR/calls.log"
for tool in yabai skhd sketchybar borders brew; do
  cat > "$MACARCHY_SEARCH_PATH/$tool" <<SH
#!/bin/sh
printf '%s\n' "$tool \$*" >>'$CALLS'
SH
  chmod +x "$MACARCHY_SEARCH_PATH/$tool"
done

fail() { echo "FAIL: $*" >&2; exit 1; }

# An existing hand-written setup, to be adopted rather than lost.
cat > "$HOME_DIR/.config/yabai/yabairc" <<'RC'
#!/usr/bin/env bash
yabai -m config window_gap 12
yabai -m config layout float
if [ -n "$EXTERNAL" ]; then
  yabai -m config top_padding 40
fi
yabai -m config left_padding "$PAD"
cat > /dev/null <<'NOTE'
yabai -m config bottom_padding 30
NOTE
echo 'multi
yabai -m config right_padding 31
line'
for app in Calculator Finder; do
  yabai -m rule --add app="^$app$" manage=off
done
RC
ORIGINAL_YABAI="$(cat "$HOME_DIR/.config/yabai/yabairc")"
echo 'cmd - h : echo mine' > "$HOME_DIR/.config/skhd/skhdrc"

mkdir -p "$HOME_DIR/.config/sketchybar"
printf '%s\n' '# >>> macarchy:keep items' 'sketchybar --add item mine left' '# <<< macarchy:keep' \
  'sketchybar --add item after right' > "$HOME_DIR/.config/sketchybar/sketchybarrc"

ORIGINAL_SKHD="$(cat "$HOME_DIR/.config/skhd/skhdrc")"
ORIGINAL_BAR="$(cat "$HOME_DIR/.config/sketchybar/sketchybarrc")"
untouched() {
  [ "$(cat "$HOME_DIR/.config/yabai/yabairc")" = "$ORIGINAL_YABAI" ] || fail "$1: yabairc changed"
  [ "$(cat "$HOME_DIR/.config/skhd/skhdrc")" = "$ORIGINAL_SKHD" ] || fail "$1: skhdrc changed"
  [ "$(cat "$HOME_DIR/.config/sketchybar/sketchybarrc")" = "$ORIGINAL_BAR" ] || fail "$1: sketchybarrc changed"
}

"$CLI" setup --keep --no-apply >/dev/null
untouched "setup"

ROOT="$HOME_DIR/Library/Application Support/Macarchy"
CONFIG="$ROOT/config"
BAR="$CONFIG/sketchybarrc"
grep -q 'add item after right' "$BAR" || fail "content after a nested region lost"
[ "$(grep -c 'macarchy:keep' "$BAR")" = 2 ] || fail "nested keep markers adopted"
[ "$(grep -n 'add item mine' "$BAR" | cut -d: -f1)" -lt "$(grep -n 'startup sketchybar' "$BAR" | cut -d: -f1)" ] \
  || fail "own bar items must run before startup"

SETTINGS="$ROOT/settings.json"
[ -f "$SETTINGS" ] || fail "settings.json not created"
[ -e "$HOME_DIR/.config/macarchy" ] && fail "the old folder was created"
grep -q '"window_gap" : 12' "$SETTINGS" || fail "yabai window_gap not adopted"
grep -q '"layout" : "float"' "$SETTINGS" || fail "yabai layout not adopted"
grep -q 'for app in Calculator Finder; do' "$CONFIG/yabairc" || fail "loop not kept"
grep -q '  yabai -m config top_padding 40' "$CONFIG/yabairc" || fail "conditional setting moved"
grep -q 'left_padding "$PAD"' "$CONFIG/yabairc" || fail "expanded value moved"
grep -q '"top_padding"' "$SETTINGS" && fail "conditional setting adopted"
grep -q '"bottom_padding"' "$SETTINGS" && fail "heredoc setting adopted"
grep -q '"right_padding"' "$SETTINGS" && fail "quoted setting adopted"
grep -q '^yabai -m config bottom_padding 30$' "$CONFIG/yabairc" || fail "heredoc body changed"
grep -q 'startup yabai' "$CONFIG/yabairc" || fail "yabairc not generated"
grep -q 'Application Support/Macarchy/Macarchy.app' "$CONFIG/yabairc" || fail "yabairc does not reach the app"
grep -q 'yabai -m config window_gap' "$CONFIG/yabairc" && fail "adopted line left in yabairc"
grep -qs 'ghostty' "$ROOT/backups/manifest.json" && fail "skipped Ghostty recorded"
[ "$(cat "$CONFIG/skhdrc")" = 'cmd - h : echo mine' ] || fail "own shortcuts not copied"
[ -d "$ROOT/themes/midnight" ] || fail "themes not installed"
grep -q 'startup sketchybar' "$BAR" || fail "sketchybarrc missing"
for rc in yabairc sketchybarrc bordersrc; do
  bash -n "$CONFIG/$rc" || fail "$rc syntax"
done
[ -f "$HOME_DIR/.config/ghostty/config" ] && fail "Ghostty configured without Ghostty"

# Each daemon gets Macarchy's agent, started with its config in Application Support.
AGENTS="$HOME_DIR/Library/LaunchAgents"
argument() { plutil -extract "ProgramArguments.$2" raw "$AGENTS/io.github.harryrandall.macarchy.$1.plist"; }
for daemon in yabai skhd sketchybar borders; do
  plutil -lint "$AGENTS/io.github.harryrandall.macarchy.$daemon.plist" >/dev/null || fail "$daemon agent missing or invalid"
done
[ "$(argument yabai 2)" = "$CONFIG/yabairc" ] || fail "yabai agent does not use Macarchy's yabairc"
[ "$(argument skhd 2)" = "$CONFIG/skhdrc" ] || fail "skhd agent does not use Macarchy's skhdrc"
[ "$(argument sketchybar 2)" = "$CONFIG/sketchybarrc" ] || fail "SketchyBar agent does not use Macarchy's sketchybarrc"
[ "$(argument borders 0)" = "$CONFIG/bordersrc" ] || fail "borders agent does not run bordersrc"

# Setting up again must not reseed or change anything already adopted.
cp "$CONFIG/yabairc" "$HOME_DIR/before"
"$CLI" setup --keep --no-apply >/dev/null
cmp -s "$HOME_DIR/before" "$CONFIG/yabairc" || fail "second setup changed yabairc"
grep -Eqs -- '--start-service|services start' "$CALLS" && fail "--no-apply started a service"

"$CLI" uninstall >/dev/null
grep -qx 'yabai --start-service' "$CALLS" || fail "uninstall did not hand yabai back"
grep -qx 'brew services start sketchybar' "$CALLS" || fail "uninstall did not hand SketchyBar back"
untouched "uninstall"
for daemon in yabai skhd sketchybar borders; do
  [ -e "$AGENTS/io.github.harryrandall.macarchy.$daemon.plist" ] && fail "$daemon agent not removed on uninstall"
done
[ -f "$SETTINGS" ] || fail "uninstall removed settings"

# A replaced setup starts from defaults and still leaves the person's files alone.
rm -rf "$CONFIG"
"$CLI" setup --replace --no-apply >/dev/null
untouched "replace"
grep -q 'ctrl + alt - left' "$CONFIG/skhdrc" || fail "default shortcuts missing"
grep -q 'for app in Calculator Finder' "$CONFIG/yabairc" && fail "replace adopted yabai commands"
"$CLI" uninstall >/dev/null

# An older ~/.skhdrc is read in place of the newer location.
rm -rf "$HOME_DIR/.config" "$CONFIG"
echo 'cmd - j : echo dotfile' > "$HOME_DIR/.skhdrc"
"$CLI" setup --keep --no-apply >/dev/null
[ "$(cat "$CONFIG/skhdrc")" = 'cmd - j : echo dotfile' ] || fail "~/.skhdrc not used"
[ "$(cat "$HOME_DIR/.skhdrc")" = 'cmd - j : echo dotfile' ] || fail "~/.skhdrc changed"
"$CLI" uninstall >/dev/null
rm -f "$HOME_DIR/.skhdrc"

# A clean Mac with Ghostty configured gets defaults and the include line.
rm -rf "$HOME_DIR/.config" "$CONFIG"
mkdir -p "$HOME_DIR/.config/ghostty"
echo 'font-size = 13' > "$HOME_DIR/.config/ghostty/config"
"$CLI" setup --replace --no-apply >/dev/null
grep -q 'ctrl + alt - left' "$CONFIG/skhdrc" || fail "default shortcuts missing"
grep -q '^font-size = 13$' "$HOME_DIR/.config/ghostty/config" || fail "Ghostty settings lost"
grep -q 'config-file = ?.*Application Support/Macarchy/generated/ghostty.conf' "$HOME_DIR/.config/ghostty/config" \
  || fail "Ghostty include missing"
"$CLI" uninstall >/dev/null
[ "$(cat "$HOME_DIR/.config/ghostty/config")" = 'font-size = 13' ] || fail "Ghostty not restored"

# With an Application Support config, the include goes there, loaded last.
SUPPORT="$HOME_DIR/Library/Application Support/com.mitchellh.ghostty"
mkdir -p "$SUPPORT"
echo 'theme = something' > "$SUPPORT/config"
"$CLI" setup --keep --no-apply >/dev/null
grep -q 'config-file = ?' "$SUPPORT/config" || fail "include not in the last-loaded file"
grep -q 'config-file' "$HOME_DIR/.config/ghostty/config" && fail "include in an earlier file"
"$CLI" uninstall >/dev/null
cp "$SETTINGS" "$HOME_DIR/settings.saved"
rm -rf "$SUPPORT" "$HOME_DIR/.config" "$ROOT"

# An install from before Application Support moves across, keeps working
# through a link until setup runs, and setup then retires the old folder.
OLD="$HOME_DIR/.config/macarchy"
mkdir -p "$OLD/themes/mine" "$HOME_DIR/.config/ghostty"
cp "$HOME_DIR/settings.saved" "$OLD/settings.json"
echo "config-file = ?$OLD/generated/ghostty.conf" > "$HOME_DIR/.config/ghostty/config"
"$CLI" doctor >/dev/null 2>&1 || true
[ -f "$ROOT/settings.json" ] || fail "settings not moved"
[ -d "$ROOT/themes/mine" ] || fail "themes not moved"
[ -L "$OLD" ] || fail "no link left at the old folder"
"$CLI" setup --keep --no-apply >/dev/null
[ -e "$OLD" ] && fail "old folder link kept after setup"
grep -q "$OLD" "$HOME_DIR/.config/ghostty/config" && fail "old Ghostty include kept"
grep -q 'Application Support/Macarchy/generated/ghostty.conf' "$HOME_DIR/.config/ghostty/config" \
  || fail "Ghostty include not moved"

echo "setup integration test passed"
