#!/bin/bash
# Runs setup and uninstall against a temporary home with fake daemons, never
# the installed desktop. Usage: macarchy/tests/integration/setup.sh
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
swift build --package-path "$REPO" -c debug >/dev/null
CLI="$(swift build --package-path "$REPO" --show-bin-path)/macarchy"

HOME_DIR="$(mktemp -d -t macarchy-setup-test)"
trap 'rm -rf "$HOME_DIR"' EXIT
export MACARCHY_HOME="$HOME_DIR" MACARCHY_RESOURCES="$REPO/macarchy/resources"
export MACARCHY_SEARCH_PATH="$HOME_DIR/fake-bin" MACARCHY_APPLICATIONS="$HOME_DIR/Applications"
mkdir -p "$MACARCHY_SEARCH_PATH" "$HOME_DIR/.config/yabai" "$HOME_DIR/.config/skhd"
for tool in yabai skhd sketchybar borders; do
  printf '#!/bin/sh\nexit 0\n' > "$MACARCHY_SEARCH_PATH/$tool"
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
for app in Calculator Finder; do
  yabai -m rule --add app="^$app$" manage=off
done
RC
ORIGINAL_YABAI="$(cat "$HOME_DIR/.config/yabai/yabairc")"
echo 'cmd - h : echo mine' > "$HOME_DIR/.config/skhd/skhdrc"

"$CLI" setup --keep --no-apply >/dev/null

SETTINGS="$HOME_DIR/.config/macarchy/settings.json"
[ -f "$SETTINGS" ] || fail "settings.json not created"
grep -q '"window_gap" : 12' "$SETTINGS" || fail "yabai window_gap not adopted"
grep -q '"layout" : "float"' "$SETTINGS" || fail "yabai layout not adopted"
grep -q 'for app in Calculator Finder; do' "$HOME_DIR/.config/yabai/yabairc" || fail "loop not kept"
grep -q '  yabai -m config top_padding 40' "$HOME_DIR/.config/yabai/yabairc" || fail "conditional setting moved"
grep -q 'left_padding "$PAD"' "$HOME_DIR/.config/yabai/yabairc" || fail "expanded value moved"
grep -q '"top_padding"' "$SETTINGS" && fail "conditional setting adopted"
grep -q 'startup yabai' "$HOME_DIR/.config/yabai/yabairc" || fail "yabairc not generated"
grep -q 'yabai -m config window_gap' "$HOME_DIR/.config/yabai/yabairc" && fail "adopted line left in yabairc"
grep -q 'ghostty' "$HOME_DIR/.config/macarchy/backups/manifest.json" && fail "skipped Ghostty recorded"
[ "$(cat "$HOME_DIR/.config/skhd/skhdrc")" = 'cmd - h : echo mine' ] || fail "kept skhdrc changed"
[ -d "$HOME_DIR/.config/macarchy/themes/midnight" ] || fail "themes not installed"
grep -q 'startup sketchybar' "$HOME_DIR/.config/sketchybar/sketchybarrc" || fail "sketchybarrc missing"
for rc in yabai/yabairc sketchybar/sketchybarrc borders/bordersrc; do
  bash -n "$HOME_DIR/.config/$rc" || fail "$rc syntax"
done
[ -f "$HOME_DIR/.config/ghostty/config" ] && fail "Ghostty configured without Ghostty"

# Setting up again must not reseed or change anything already adopted.
cp "$HOME_DIR/.config/yabai/yabairc" "$HOME_DIR/before"
"$CLI" setup --keep --no-apply >/dev/null
cmp -s "$HOME_DIR/before" "$HOME_DIR/.config/yabai/yabairc" || fail "second setup changed yabairc"

"$CLI" uninstall >/dev/null
[ "$(cat "$HOME_DIR/.config/yabai/yabairc")" = "$ORIGINAL_YABAI" ] || fail "yabairc not restored"
[ "$(cat "$HOME_DIR/.config/skhd/skhdrc")" = 'cmd - h : echo mine' ] || fail "skhdrc not restored"
[ -e "$HOME_DIR/.config/sketchybar/sketchybarrc" ] && fail "created sketchybarrc not removed"

# Setting up again after uninstalling adopts the restored files afresh.
"$CLI" setup --keep --no-apply >/dev/null
grep -q 'for app in Calculator Finder; do' "$HOME_DIR/.config/yabai/yabairc" || fail "reinstall lost yabai commands"
"$CLI" uninstall >/dev/null
[ "$(cat "$HOME_DIR/.config/yabai/yabairc")" = "$ORIGINAL_YABAI" ] || fail "second uninstall did not restore"

# An older ~/.skhdrc is used in place, and a symlinked config comes back as a link.
rm -rf "$HOME_DIR/.config"
mkdir -p "$HOME_DIR/dotfiles" "$HOME_DIR/.config/yabai"
echo 'cmd - j : echo dotfile' > "$HOME_DIR/.skhdrc"
echo 'yabai -m config window_gap 5' > "$HOME_DIR/dotfiles/yabairc"
ln -s "$HOME_DIR/dotfiles/yabairc" "$HOME_DIR/.config/yabai/yabairc"
"$CLI" setup --keep --no-apply >/dev/null
[ -e "$HOME_DIR/.config/skhd/skhdrc" ] && fail "defaults shadow ~/.skhdrc"
[ "$(cat "$HOME_DIR/dotfiles/yabairc")" = 'yabai -m config window_gap 5' ] || fail "dotfile target changed"
"$CLI" uninstall >/dev/null
[ -L "$HOME_DIR/.config/yabai/yabairc" ] || fail "symlink not restored"
rm -f "$HOME_DIR/.skhdrc"

# A clean Mac with Ghostty configured gets defaults and the include line.
rm -rf "$HOME_DIR/.config"
mkdir -p "$HOME_DIR/.config/ghostty"
echo 'font-size = 13' > "$HOME_DIR/.config/ghostty/config"
"$CLI" setup --replace --no-apply >/dev/null
grep -q 'ctrl + alt - left' "$HOME_DIR/.config/skhd/skhdrc" || fail "default shortcuts missing"
grep -q '^font-size = 13$' "$HOME_DIR/.config/ghostty/config" || fail "Ghostty settings lost"
grep -q 'config-file = ?' "$HOME_DIR/.config/ghostty/config" || fail "Ghostty include missing"
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

echo "setup integration test passed"
