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
# Queries for lists answer as the real tools do when nothing is set.
CALLS="$HOME_DIR/calls.log"
for tool in yabai skhd sketchybar borders brew; do
  cat > "$MACARCHY_SEARCH_PATH/$tool" <<SH
#!/bin/sh
printf '%s\n' "$tool \$*" >>'$CALLS'
case "\$*" in *--list*) echo '[]' ;; esac
SH
  chmod +x "$MACARCHY_SEARCH_PATH/$tool"
done

fail() { echo "FAIL: $*" >&2; exit 1; }
status() { "$@" >/dev/null 2>&1; echo $?; }

# Help and mistyped arguments never run the command.
"$CLI" setup --help | grep -q 'Usage: macarchy setup' || fail "setup --help shows no usage"
[ -e "$HOME_DIR/.config/macarchy" ] && fail "setup --help ran setup"
[ "$(status "$CLI" setup --replce)" = 2 ] || fail "unknown setup option accepted"
[ "$(status "$CLI" setup --keep --replace)" = 2 ] || fail "conflicting setup options accepted"
[ "$(status "$CLI" rules togle)" = 2 ] || fail "unknown rules argument accepted"
[ "$(status "$CLI" space 0)" = 2 ] || fail "out-of-range Space accepted"
[ "$(status "$CLI" widget clik x)" = 2 ] || fail "unknown widget command accepted"
[ -e "$HOME_DIR/.config/macarchy" ] && fail "a rejected command changed files"

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

"$CLI" setup --keep --no-apply >/dev/null

"$CLI" uninstall --help >/dev/null
grep -q 'startup yabai' "$HOME_DIR/.config/yabai/yabairc" || fail "uninstall --help uninstalled"

BAR="$HOME_DIR/.config/sketchybar/sketchybarrc"
grep -q 'add item after right' "$BAR" || fail "content after a nested region lost"
[ "$(grep -c 'macarchy:keep' "$BAR")" = 2 ] || fail "nested keep markers adopted"
[ "$(grep -n 'add item mine' "$BAR" | cut -d: -f1)" -lt "$(grep -n 'startup sketchybar' "$BAR" | cut -d: -f1)" ] \
  || fail "own bar items must run before startup"

SETTINGS="$HOME_DIR/.config/macarchy/settings.json"
[ -f "$SETTINGS" ] || fail "settings.json not created"
grep -q '"window_gap" : 12' "$SETTINGS" || fail "yabai window_gap not adopted"
grep -q '"layout" : "float"' "$SETTINGS" || fail "yabai layout not adopted"
grep -q 'for app in Calculator Finder; do' "$HOME_DIR/.config/yabai/yabairc" || fail "loop not kept"
grep -q '  yabai -m config top_padding 40' "$HOME_DIR/.config/yabai/yabairc" || fail "conditional setting moved"
grep -q 'left_padding "$PAD"' "$HOME_DIR/.config/yabai/yabairc" || fail "expanded value moved"
grep -q '"top_padding"' "$SETTINGS" && fail "conditional setting adopted"
grep -q '"bottom_padding"' "$SETTINGS" && fail "heredoc setting adopted"
grep -q '"right_padding"' "$SETTINGS" && fail "quoted setting adopted"
grep -q '^yabai -m config bottom_padding 30$' "$HOME_DIR/.config/yabai/yabairc" || fail "heredoc body changed"
grep -q 'startup yabai' "$HOME_DIR/.config/yabai/yabairc" || fail "yabairc not generated"
grep -q 'yabai -m config window_gap' "$HOME_DIR/.config/yabai/yabairc" && fail "adopted line left in yabairc"
grep -q 'ghostty' "$HOME_DIR/.config/macarchy/backups/manifest.json" && fail "skipped Ghostty recorded"
[ "$(cat "$HOME_DIR/.config/skhd/skhdrc")" = 'cmd - h : echo mine' ] || fail "kept skhdrc changed"
[ -d "$HOME_DIR/.config/macarchy/themes/midnight" ] || fail "themes not installed"
AGENT="$HOME_DIR/Library/LaunchAgents/io.github.harryrandall.macarchy.borders.plist"
plutil -lint "$AGENT" >/dev/null || fail "borders agent missing or invalid"
plutil -extract ProgramArguments.0 raw "$AGENT" | grep -q 'borders/bordersrc' || fail "agent does not run bordersrc"
grep -q 'startup sketchybar' "$HOME_DIR/.config/sketchybar/sketchybarrc" || fail "sketchybarrc missing"
for rc in yabai/yabairc sketchybar/sketchybarrc borders/bordersrc; do
  bash -n "$HOME_DIR/.config/$rc" || fail "$rc syntax"
done
[ -f "$HOME_DIR/.config/ghostty/config" ] && fail "Ghostty configured without Ghostty"

# Setting up again must not reseed or change anything already adopted.
cp "$HOME_DIR/.config/yabai/yabairc" "$HOME_DIR/before"
"$CLI" setup --keep --no-apply >/dev/null
cmp -s "$HOME_DIR/before" "$HOME_DIR/.config/yabai/yabairc" || fail "second setup changed yabairc"
grep -Eqs -- '--start-service|services start' "$CALLS" && fail "--no-apply started a service"

# Edits outside the keep region are replaced on the next setup, and said so.
printf 'echo edited\n' >> "$HOME_DIR/.config/yabai/yabairc"
OUTPUT="$("$CLI" setup --keep --no-apply)"
grep -q 'Replaced edits to yabairc made outside its keep region; your edited copy is saved as snapshot' <<<"$OUTPUT" \
  || fail "replaced edits not reported: $OUTPUT"
grep -q 'echo edited' "$HOME_DIR/.config/yabai/yabairc" && fail "edit outside the keep region kept"
grep -rq 'echo edited' "$HOME_DIR/.config/macarchy/snapshots" || fail "edited yabairc not snapshotted"

"$CLI" uninstall >/dev/null
DOCTOR="$("$CLI" doctor 2>&1 || true)"
grep -q 'Edited outside' <<<"$DOCTOR" && fail "doctor reports restored originals as edited"
[ "$(status env MACARCHY_SEARCH_PATH= "$CLI" startup yabai)" = 1 ] || fail "empty search path crashed"
grep -qx 'yabai --start-service' "$CALLS" || fail "uninstall did not start yabai"
grep -qx 'brew services start sketchybar' "$CALLS" || fail "uninstall did not start SketchyBar"
[ "$(cat "$HOME_DIR/.config/yabai/yabairc")" = "$ORIGINAL_YABAI" ] || fail "yabairc not restored"
[ "$(cat "$HOME_DIR/.config/skhd/skhdrc")" = 'cmd - h : echo mine' ] || fail "skhdrc not restored"
grep -q 'add item after right' "$HOME_DIR/.config/sketchybar/sketchybarrc" || fail "sketchybarrc not restored"
[ -e "$AGENT" ] && fail "borders agent not removed on uninstall"
rm -f "$HOME_DIR/.config/sketchybar/sketchybarrc"

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

# A Ghostty config linked from a dotfiles folder stays a link; the include is
# written into the file it points at and removed again on uninstall.
rm -rf "$HOME_DIR/.config"
mkdir -p "$HOME_DIR/.config/ghostty" "$HOME_DIR/dotfiles"
echo 'font-size = 14' > "$HOME_DIR/dotfiles/ghostty-config"
chmod 600 "$HOME_DIR/dotfiles/ghostty-config"
ln -s "$HOME_DIR/dotfiles/ghostty-config" "$HOME_DIR/.config/ghostty/config"
"$CLI" setup --keep --no-apply >/dev/null
[ -L "$HOME_DIR/.config/ghostty/config" ] || fail "Ghostty link replaced with a copy"
grep -q 'config-file = ?' "$HOME_DIR/dotfiles/ghostty-config" || fail "include not in the link target"
[ "$(stat -f %Lp "$HOME_DIR/dotfiles/ghostty-config")" = 600 ] || fail "Ghostty permissions changed"
"$CLI" uninstall >/dev/null
[ -L "$HOME_DIR/.config/ghostty/config" ] || fail "Ghostty link not kept on uninstall"
[ "$(cat "$HOME_DIR/dotfiles/ghostty-config")" = 'font-size = 14' ] || fail "include left in the link target"
rm -rf "$HOME_DIR/dotfiles" "$HOME_DIR/.config/ghostty/config"
echo 'font-size = 13' > "$HOME_DIR/.config/ghostty/config"

# With an Application Support config, the include goes there, loaded last.
SUPPORT="$HOME_DIR/Library/Application Support/com.mitchellh.ghostty"
mkdir -p "$SUPPORT"
echo 'theme = something' > "$SUPPORT/config"
"$CLI" setup --keep --no-apply >/dev/null
grep -q 'config-file = ?' "$SUPPORT/config" || fail "include not in the last-loaded file"
grep -q 'config-file' "$HOME_DIR/.config/ghostty/config" && fail "include in an earlier file"
"$CLI" uninstall >/dev/null

# An uninstall that stops part way says what it had already restored, and a
# second run finishes.
rm -rf "$HOME_DIR/.config"
mkdir -p "$HOME_DIR/.config/yabai" "$HOME_DIR/.config/sketchybar"
echo 'yabai -m config window_gap 3' > "$HOME_DIR/.config/yabai/yabairc"
echo 'sketchybar --bar height=20' > "$HOME_DIR/.config/sketchybar/sketchybarrc"
"$CLI" setup --keep --no-apply >/dev/null
chmod 555 "$HOME_DIR/.config/yabai"
OUTPUT="$("$CLI" uninstall 2>&1)" && fail "uninstall into a read-only folder succeeded"
chmod 755 "$HOME_DIR/.config/yabai"
grep -q 'Uninstall stopped part way' <<<"$OUTPUT" || fail "partial uninstall not reported: $OUTPUT"
grep -q 'Restored ~/.config/sketchybar/sketchybarrc' <<<"$OUTPUT" || fail "restored files not listed: $OUTPUT"
"$CLI" uninstall >/dev/null || fail "second uninstall did not finish"
[ "$(cat "$HOME_DIR/.config/yabai/yabairc")" = 'yabai -m config window_gap 3' ] || fail "yabairc not restored on retry"

# A missing backup stops uninstall before anything changes.
rm -rf "$HOME_DIR/.config"
mkdir -p "$HOME_DIR/.config/yabai"
echo 'yabai -m config window_gap 3' > "$HOME_DIR/.config/yabai/yabairc"
"$CLI" setup --keep --no-apply >/dev/null
GENERATED="$(cat "$HOME_DIR/.config/yabai/yabairc")"
rm "$HOME_DIR/.config/macarchy/backups/"*-yabairc
"$CLI" uninstall >/dev/null 2>&1 && fail "uninstall succeeded with a missing backup"
[ "$(cat "$HOME_DIR/.config/yabai/yabairc")" = "$GENERATED" ] || fail "file changed despite a missing backup"

# A bar written for another interpreter is not wrapped in bash: --keep stops
# before changing anything and says what to do.
rm -rf "$HOME_DIR/.config"
mkdir -p "$HOME_DIR/.config/sketchybar" "$HOME_DIR/.config/yabai"
printf '#!/usr/bin/env lua\nsbar = require("sketchybar")\n' > "$HOME_DIR/.config/sketchybar/sketchybarrc"
echo 'yabai -m config window_gap 4' > "$HOME_DIR/.config/yabai/yabairc"
OUTPUT="$("$CLI" setup --keep --no-apply 2>&1)" && fail "setup kept a Lua sketchybarrc"
grep -q 'runs with lua' <<<"$OUTPUT" || fail "Lua refusal not explained: $OUTPUT"
grep -q 'some files may already have changed' <<<"$OUTPUT" && fail "refusal claims changes: $OUTPUT"
grep -q 'require("sketchybar")' "$HOME_DIR/.config/sketchybar/sketchybarrc" || fail "Lua bar changed"
[ "$(cat "$HOME_DIR/.config/yabai/yabairc")" = 'yabai -m config window_gap 4' ] || fail "yabairc changed by a refused setup"
[ -e "$HOME_DIR/.config/macarchy/backups" ] && fail "refused setup wrote backups"
printf '#!/bin/bash\nif then\n' > "$HOME_DIR/.config/sketchybar/sketchybarrc"
"$CLI" setup --keep --no-apply >/dev/null 2>&1 && fail "setup kept a sketchybarrc bash cannot parse"
"$CLI" setup --replace --no-apply >/dev/null || fail "replace refused a non-bash bar"
bash -n "$HOME_DIR/.config/sketchybar/sketchybarrc" || fail "replaced sketchybarrc syntax"
"$CLI" uninstall >/dev/null
grep -q 'if then' "$HOME_DIR/.config/sketchybar/sketchybarrc" || fail "replaced bar not restored"

# A full setup, apply and theme change in the temporary home reach only the
# fake tools. launchd, defaults, the appearance, the wallpaper, running apps
# and the bundled bar scripts are refused (see DesktopIsolation), so the real
# desktop is left alone even though nothing here is a dry run.
rm -rf "$HOME_DIR/.config" "$HOME_DIR/Library" "$CALLS"
"$CLI" setup --replace >/dev/null || fail "isolated setup with services failed"
"$CLI" apply >/dev/null || fail "isolated apply failed"
# A copied theme folder whose manifest still names the original is stepped over.
cp -R "$HOME_DIR/.config/macarchy/themes/midnight" "$HOME_DIR/.config/macarchy/themes/midnight-copy"
"$CLI" theme next >/dev/null || fail "isolated theme change failed"
grep -q '"currentTheme" : "turbonite"' "$HOME_DIR/.config/macarchy/settings.json" || fail "theme next did not advance"
OUTPUT="$("$CLI" theme midnight-copy 2>&1)" && fail "mismatched theme folder applied"
grep -q 'folder midnight-copy contains the theme midnight' <<<"$OUTPUT" || fail "mismatch not explained: $OUTPUT"
grep -q 'may already have applied' <<<"$OUTPUT" && fail "untouched desktop reported as partly changed"
grep -q '^yabai -m config' "$CALLS" || fail "apply did not reach the fake yabai"
"$CLI" uninstall >/dev/null || fail "isolated uninstall failed"

echo "setup integration test passed"
