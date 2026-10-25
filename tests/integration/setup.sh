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
# yabai and SketchyBar run the file they are started with as the real ones
# do, as `sh -c <path>` with the path unquoted, so a path sh would split
# fails here as it does on a Mac. SketchyBar first resolves links and moves
# to the file's folder, which it gives the bar as $CONFIG_DIR.
CALLS="$HOME_DIR/calls.log"
for tool in yabai skhd sketchybar borders brew; do
  cat > "$MACARCHY_SEARCH_PATH/$tool" <<SH
#!/bin/sh
printf '%s\n' "$tool \$*" >>'$CALLS'
case "$tool \$1" in
  "yabai -c") [ -x "\$2" ] && exec /usr/bin/env sh -c "\$2"; exec /usr/bin/env sh "\$2" ;;
  "sketchybar --config")
    file="\$(realpath "\$2")" || exit 1
    CONFIG_DIR="\$(dirname "\$file")"; export CONFIG_DIR; cd "\$CONFIG_DIR" || exit 1
    exec /usr/bin/env sh -c "\$file" ;;
esac
case "\$*" in *--list*) echo '[]' ;; esac
SH
  chmod +x "$MACARCHY_SEARCH_PATH/$tool"
done

fail() { echo "FAIL: $*" >&2; exit 1; }
status() { "$@" >/dev/null 2>&1; echo $?; }
ROOT="$HOME_DIR/Library/Application Support/Macarchy"
CONFIG="$ROOT/config"
AGENTS="$HOME_DIR/Library/LaunchAgents"

# Help and mistyped arguments never run the command.
"$CLI" setup --help | grep -q 'Usage: macarchy setup' || fail "setup --help shows no usage"
[ -e "$ROOT/settings.json" ] && fail "setup --help ran setup"
[ "$(status "$CLI" setup --replce)" = 2 ] || fail "unknown setup option accepted"
[ "$(status "$CLI" setup --keep --replace)" = 2 ] || fail "conflicting setup options accepted"
[ "$(status "$CLI" rules togle)" = 2 ] || fail "unknown rules argument accepted"
[ "$(status "$CLI" space 0)" = 2 ] || fail "out-of-range Space accepted"
[ "$(status "$CLI" widget clik x)" = 2 ] || fail "unknown widget command accepted"
[ -e "$ROOT/settings.json" ] && fail "a rejected command changed files"

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

"$CLI" uninstall --help >/dev/null
[ -e "$AGENTS/io.github.harryrandall.macarchy.yabai.plist" ] || fail "uninstall --help uninstalled"

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
argument() { plutil -extract "ProgramArguments.$2" raw "$AGENTS/io.github.harryrandall.macarchy.$1.plist"; }
for daemon in yabai skhd sketchybar borders; do
  plutil -lint "$AGENTS/io.github.harryrandall.macarchy.$daemon.plist" >/dev/null || fail "$daemon agent missing or invalid"
done
[ "$(argument skhd 2)" = "$CONFIG/skhdrc" ] || fail "skhd agent does not use Macarchy's skhdrc"
# yabai and SketchyBar run the file they start with through sh unquoted, so
# they start from launchers in their own folders, whose paths have no space,
# and each hands over to Macarchy's file. The kept bar's items also see its
# folder as $CONFIG_DIR.
YABAI_LAUNCHER="$HOME_DIR/.config/yabai/macarchy-yabairc"
LAUNCHER="$HOME_DIR/.config/sketchybar/macarchy-sketchybarrc"
[ "$(argument yabai 2)" = "$YABAI_LAUNCHER" ] || fail "yabai agent does not start from its launcher"
[ "$(argument sketchybar 2)" = "$LAUNCHER" ] || fail "SketchyBar agent does not start the kept bar from its folder"
grep -q '^exec "$HOME/Library/Application Support/Macarchy/config/yabairc" "$@"$' "$YABAI_LAUNCHER" \
  || fail "launcher does not hand over to Macarchy's yabairc"
grep -q '^exec "$HOME/Library/Application Support/Macarchy/config/sketchybarrc" "$@"$' "$LAUNCHER" \
  || fail "launcher does not hand over to Macarchy's sketchybarrc"
[ -x "$YABAI_LAUNCHER" ] && [ -x "$LAUNCHER" ] || fail "launchers not executable"
[ "$(argument borders 0)" = "$CONFIG/bordersrc" ] || fail "borders agent does not run bordersrc"

# Setting up again must not reseed or change anything already adopted.
cp "$CONFIG/yabairc" "$HOME_DIR/before"
"$CLI" setup --keep --no-apply >/dev/null
cmp -s "$HOME_DIR/before" "$CONFIG/yabairc" || fail "second setup changed yabairc"
grep -Eqs -- '--start-service|services start' "$CALLS" && fail "--no-apply started a service"

# Edits outside the keep region are replaced on the next setup, and said so.
printf 'echo edited\n' >> "$CONFIG/yabairc"
OUTPUT="$("$CLI" setup --keep --no-apply)"
grep -q 'Replaced edits to yabairc made outside its keep region; your edited copy is saved as snapshot' <<<"$OUTPUT" \
  || fail "replaced edits not reported: $OUTPUT"
grep -q 'echo edited' "$CONFIG/yabairc" && fail "edit outside the keep region kept"
grep -rq 'echo edited' "$ROOT/snapshots" || fail "edited yabairc not snapshotted"

"$CLI" uninstall >/dev/null
DOCTOR="$("$CLI" doctor 2>&1 || true)"
grep -q 'Edited outside' <<<"$DOCTOR" && fail "doctor reports Macarchy's unused configs as edited"
[ "$(status env MACARCHY_SEARCH_PATH= "$CLI" startup yabai)" = 1 ] || fail "empty search path crashed"
grep -qx 'yabai --start-service' "$CALLS" || fail "uninstall did not hand yabai back"
grep -qx 'brew services start sketchybar' "$CALLS" || fail "uninstall did not hand SketchyBar back"
untouched "uninstall"
for daemon in yabai skhd sketchybar borders; do
  [ -e "$AGENTS/io.github.harryrandall.macarchy.$daemon.plist" ] && fail "$daemon agent not removed on uninstall"
done
[ -e "$YABAI_LAUNCHER" ] && fail "uninstall left the yabai launcher"
[ -e "$LAUNCHER" ] && fail "uninstall left the bar launcher"
[ -f "$SETTINGS" ] || fail "uninstall removed settings"

# A replaced setup starts from defaults and still leaves the person's files alone.
rm -rf "$CONFIG"
"$CLI" setup --replace --no-apply >/dev/null
untouched "replace"
grep -q 'ctrl + alt - left' "$CONFIG/skhdrc" || fail "default shortcuts missing"
grep -q 'for app in Calculator Finder' "$CONFIG/yabairc" && fail "replace adopted yabai commands"
# Macarchy's own bar starts from the launcher too: SketchyBar would split its path as well.
[ "$(argument sketchybar 2)" = "$LAUNCHER" ] || fail "SketchyBar agent does not start Macarchy's bar from the launcher"
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
cp "$SETTINGS" "$HOME_DIR/settings.saved"
rm -rf "$SUPPORT" "$HOME_DIR/.config" "$ROOT"

# An install from before Application Support moves across and keeps working
# through a link, which setup keeps for files that still name the old folder
# and uninstall removes. tests/integration/upgrade.sh covers a full upgrade.
OLD="$HOME_DIR/.config/macarchy"
mkdir -p "$OLD/themes/mine" "$HOME_DIR/.config/ghostty"
cp "$HOME_DIR/settings.saved" "$OLD/settings.json"
echo "config-file = ?$OLD/generated/ghostty.conf" > "$HOME_DIR/.config/ghostty/config"
"$CLI" doctor >/dev/null 2>&1 || true
[ -f "$ROOT/settings.json" ] || fail "settings not moved"
[ -d "$ROOT/themes/mine" ] || fail "themes not moved"
[ -L "$OLD" ] || fail "no link left at the old folder"
"$CLI" setup --keep --no-apply >/dev/null
[ -L "$OLD" ] || fail "old folder link removed by setup"
grep -q 'Set up before Macarchy moved' <<<"$("$CLI" doctor 2>&1 || true)" && fail "setup still needed after setup"
grep -q "$OLD" "$HOME_DIR/.config/ghostty/config" && fail "old Ghostty include kept"
grep -q 'Application Support/Macarchy/generated/ghostty.conf' "$HOME_DIR/.config/ghostty/config" \
  || fail "Ghostty include not moved"
"$CLI" uninstall >/dev/null
[ -e "$OLD" ] && fail "old folder link kept after uninstall"

# An uninstall that stops part way says what it had already restored, and a
# second run finishes. Backups are restored in path order, so Ghostty's
# config comes back before the agents, whose folder cannot be changed.
rm -rf "$HOME_DIR/.config" "$CONFIG"
mkdir -p "$HOME_DIR/.config/ghostty"
echo 'font-size = 14' > "$HOME_DIR/.config/ghostty/config"
"$CLI" setup --replace --no-apply >/dev/null
chmod 555 "$AGENTS"
OUTPUT="$("$CLI" uninstall 2>&1)" && fail "uninstall from a read-only agents folder succeeded"
chmod 755 "$AGENTS"
grep -q 'Uninstall stopped part way' <<<"$OUTPUT" || fail "partial uninstall not reported: $OUTPUT"
grep -q 'Restored ~/.config/ghostty/config' <<<"$OUTPUT" || fail "restored files not listed: $OUTPUT"
"$CLI" uninstall >/dev/null || fail "second uninstall did not finish"
[ "$(cat "$HOME_DIR/.config/ghostty/config")" = 'font-size = 14' ] || fail "Ghostty not restored on retry"
for daemon in yabai skhd sketchybar borders; do
  [ -e "$AGENTS/io.github.harryrandall.macarchy.$daemon.plist" ] && fail "$daemon agent left after retry"
done

# A missing backup stops uninstall before anything changes.
"$CLI" setup --replace --no-apply >/dev/null
INCLUDED="$(cat "$HOME_DIR/.config/ghostty/config")"
rm "$ROOT/backups/"*-config
"$CLI" uninstall >/dev/null 2>&1 && fail "uninstall succeeded with a missing backup"
[ "$(cat "$HOME_DIR/.config/ghostty/config")" = "$INCLUDED" ] || fail "file changed despite a missing backup"
[ -e "$AGENTS/io.github.harryrandall.macarchy.yabai.plist" ] || fail "agent removed despite a missing backup"
rm -rf "$ROOT/backups" "$AGENTS"

# A bar written for another interpreter is not wrapped in bash: --keep stops
# before changing anything and says what to do.
rm -rf "$HOME_DIR/.config" "$ROOT"
mkdir -p "$HOME_DIR/.config/sketchybar" "$HOME_DIR/.config/yabai"
printf '#!/usr/bin/env lua\nsbar = require("sketchybar")\n' > "$HOME_DIR/.config/sketchybar/sketchybarrc"
echo 'yabai -m config window_gap 4' > "$HOME_DIR/.config/yabai/yabairc"
OUTPUT="$("$CLI" setup --keep --no-apply 2>&1)" && fail "setup kept a Lua sketchybarrc"
grep -q 'runs with lua' <<<"$OUTPUT" || fail "Lua refusal not explained: $OUTPUT"
grep -q 'some files may already have changed' <<<"$OUTPUT" && fail "refusal claims changes: $OUTPUT"
grep -q 'require("sketchybar")' "$HOME_DIR/.config/sketchybar/sketchybarrc" || fail "Lua bar changed"
[ "$(cat "$HOME_DIR/.config/yabai/yabairc")" = 'yabai -m config window_gap 4' ] || fail "yabairc changed by a refused setup"
[ -e "$ROOT/backups" ] && fail "refused setup wrote backups"
[ -e "$CONFIG" ] && fail "refused setup wrote configs"
printf '#!/bin/bash\nif then\n' > "$HOME_DIR/.config/sketchybar/sketchybarrc"
"$CLI" setup --keep --no-apply >/dev/null 2>&1 && fail "setup kept a sketchybarrc bash cannot parse"
"$CLI" setup --replace --no-apply >/dev/null || fail "replace refused a non-bash bar"
bash -n "$CONFIG/sketchybarrc" || fail "replaced sketchybarrc syntax"
grep -q 'if then' "$HOME_DIR/.config/sketchybar/sketchybarrc" || fail "replace changed the person's bar"
"$CLI" uninstall >/dev/null

# A full setup, apply and theme change in the temporary home reach only the
# fake tools. launchd is reached only through a fake launchctl on the search
# path; defaults, the appearance, the wallpaper, running apps and the bundled
# bar scripts are refused (see DesktopIsolation), so the real desktop is left
# alone even though nothing here is a dry run.
rm -rf "$HOME_DIR/.config" "$HOME_DIR/Library" "$CALLS"
# It keeps a list of loaded jobs, so a job reads as loaded only between its
# bootstrap and bootout, as with launchd.
LOADED="$HOME_DIR/loaded.log"
cat > "$MACARCHY_SEARCH_PATH/launchctl" <<SH
#!/bin/sh
printf '%s\n' "launchctl \$*" >>'$CALLS'
touch '$LOADED'
case "\$1" in
  print) grep -qx "\${2##*/}" '$LOADED' || exit 113
    printf 'state = running\npid = 4242\n' ;;
  bootstrap) basename "\$3" .plist >>'$LOADED' ;;
  bootout) grep -vx "\${2##*/}" '$LOADED' >'$LOADED.next'; mv '$LOADED.next' '$LOADED' ;;
esac
SH
chmod +x "$MACARCHY_SEARCH_PATH/launchctl"
# Set up from a copy of the command inside an app, as installed, so the
# startup files reach this build through the app link.
APP="$HOME_DIR/Applications/Macarchy.app"
mkdir -p "$APP/Contents/MacOS"
cp "$CLI" "$APP/Contents/MacOS/macarchy"
"$APP/Contents/MacOS/macarchy" setup --replace >/dev/null || fail "isolated setup with services failed"
grep -q '^launchctl kickstart -k .*io.github.harryrandall.macarchy.yabai$' "$CALLS" \
  || fail "setup did not start yabai from Macarchy's agent"
# The fake launchctl starts nothing, so no daemon has run its startup file yet.
DOCTOR="$("$CLI" doctor 2>&1 || true)"
for daemon in yabai SketchyBar borders; do
  grep -q "FAIL $daemon: Running, but it has not run its startup file" <<<"$DOCTOR" \
    || fail "doctor does not report that $daemon skipped its startup file: $DOCTOR"
done
# The fake yabai runs a file as yabai does, so the path agents used to name
# fails as it did on a Mac.
OUTPUT="$(env HOME="$HOME_DIR" "$MACARCHY_SEARCH_PATH/yabai" -c "$CONFIG/yabairc" 2>&1)" \
  && fail "the fake yabai ran a file in Application Support through sh -c"
grep -q 'Library/Application: No such file' <<<"$OUTPUT" || fail "the fake yabai did not split the path: $OUTPUT"
# Start each daemon as launchd does: its agent's arguments, run directly with
# the agent's PATH and no shell in between. Each must reach its startup.
run_agent() {
  local plist="$AGENTS/io.github.harryrandall.macarchy.$1.plist" index=0 argument
  local arguments=()
  while argument="$(plutil -extract "ProgramArguments.$index" raw "$plist" 2>/dev/null)"; do
    arguments+=("$argument")
    index=$((index + 1))
  done
  env HOME="$HOME_DIR" PATH="$(plutil -extract EnvironmentVariables.PATH raw "$plist")" "${arguments[@]}"
}
: > "$CALLS"
OUTPUT="$(run_agent yabai 2>&1)" || fail "yabai did not run its startup file: $OUTPUT"
grep -q '^yabai -m config layout ' "$CALLS" || fail "yabai's startup file set no layout: $OUTPUT"
grep -q '^yabai -m signal --add label=macarchy_window_created ' "$CALLS" || fail "yabai's startup file added no signals"
OUTPUT="$(run_agent sketchybar 2>&1)" || fail "SketchyBar did not run its startup file: $OUTPUT"
grep -q '^sketchybar --bar ' "$CALLS" || fail "SketchyBar's startup file set up no bar: $OUTPUT"
OUTPUT="$(run_agent borders 2>&1)" || fail "borders did not run its startup file: $OUTPUT"
grep -q '^borders .*active_color=' "$CALLS" || fail "bordersrc did not start borders: $OUTPUT"
DOCTOR="$("$CLI" doctor 2>&1 || true)"
grep -q 'has not run its startup file' <<<"$DOCTOR" && fail "doctor reports a startup file that ran: $DOCTOR"
grep -q 'agent: Macarchy' <<<"$DOCTOR" && fail "doctor reports a start file problem: $DOCTOR"
"$CLI" apply >/dev/null || fail "isolated apply failed"
# A copied theme folder whose manifest still names the original is stepped over.
cp -R "$ROOT/themes/midnight" "$ROOT/themes/midnight-copy"
"$CLI" theme next >/dev/null || fail "isolated theme change failed"
grep -q '"currentTheme" : "turbonite"' "$SETTINGS" || fail "theme next did not advance"
OUTPUT="$("$CLI" theme midnight-copy 2>&1)" && fail "mismatched theme folder applied"
grep -q 'folder midnight-copy contains the theme midnight' <<<"$OUTPUT" || fail "mismatch not explained: $OUTPUT"
grep -q 'may already have applied' <<<"$OUTPUT" && fail "untouched desktop reported as partly changed"
grep -q '^yabai -m config' "$CALLS" || fail "apply did not reach the fake yabai"
"$CLI" uninstall >/dev/null || fail "isolated uninstall failed"
rm "$MACARCHY_SEARCH_PATH/launchctl"

# A Space click still reaches a custom yabai in Macarchy's bin, whose path has
# a space in it. The bar script runs in a home of its own with fake tools.
BAR_HOME="$HOME_DIR/bar-home"
BAR_BIN="$BAR_HOME/Library/Application Support/Macarchy/bin"
mkdir -p "$BAR_BIN"
cat > "$BAR_BIN/yabai" <<SH
#!/bin/sh
case "\$*" in
  "-m query"*) echo '[]' ;;
  *) printf '%s\n' "yabai \$*" >>'$CALLS' ;;
esac
SH
printf '#!/bin/sh\ncat >/dev/null\nprintf "1\\t1\\t\\n"\n' > "$BAR_BIN/jq"
cat > "$BAR_BIN/sketchybar" <<SH
#!/bin/sh
printf '%s\n' "\$@" >'$HOME_DIR/bar-arguments'
SH
chmod +x "$BAR_BIN/yabai" "$BAR_BIN/jq" "$BAR_BIN/sketchybar"
: > "$CALLS"
HOME="$BAR_HOME" "$REPO/resources/integrations/sketchybar/plugins/spaces.sh" --reconcile
CLICK="$(grep -m1 '^click_script=' "$HOME_DIR/bar-arguments")" || fail "no Space click script"
sh -c "${CLICK#click_script=}" || fail "Space click script failed: $CLICK"
grep -qx 'yabai -m space --focus 1' "$CALLS" || fail "Space click did not reach yabai: $CLICK"

echo "setup integration test passed"
"$REPO/tests/integration/upgrade.sh"
