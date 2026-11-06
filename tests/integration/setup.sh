#!/bin/bash
# Runs setup and uninstall against a temporary home with fake daemons, never
# the installed desktop. Usage: tests/integration/setup.sh
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
swift build --package-path "$REPO" -c debug >/dev/null
CLI="$(swift build --package-path "$REPO" --show-bin-path)/macarchy"

HOME_DIR="$(mktemp -d -t macarchy-setup-test)"
RESOURCES="$(mktemp -d -t macarchy-setup-resources)"
# The partial uninstall check locks a file; unlock everything before removing.
trap 'chflags -R nouchg "$HOME_DIR" 2>/dev/null; rm -rf "$HOME_DIR" "$RESOURCES"' EXIT
"$REPO/tools/stage-resources.sh" "$RESOURCES"
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

OUTPUT="$("$CLI" setup --keep --no-apply)"
untouched "setup"
grep -q 'Left ~/.config/sketchybar/sketchybarrc as it is: the menu bar shows Macarchy' <<<"$OUTPUT" \
  || fail "own bar left unused not reported: $OUTPUT"

"$CLI" uninstall --help >/dev/null
[ -e "$AGENTS/io.github.harryrandall.macarchy.yabai.plist" ] || fail "uninstall --help uninstalled"

# The bar is Macarchy's widgets whatever setup starts from: a sketchybarrc of
# the person's own is left as it is and never runs.
BAR="$CONFIG/sketchybarrc"
grep -q 'add item' "$BAR" && fail "own bar adopted into Macarchy's sketchybarrc"
[ "$(grep -c 'macarchy:keep' "$BAR")" = 2 ] || fail "sketchybarrc keep region missing"
[ "$(grep -n 'startup sketchybar' "$BAR" | cut -d: -f1)" -lt "$(grep -n 'macarchy:keep yours' "$BAR" | cut -d: -f1)" ] \
  || fail "the person's commands must run after the widget bar is set up"

SETTINGS="$ROOT/settings.json"
[ -f "$SETTINGS" ] || fail "settings.json not created"
python3 - "$SETTINGS" <<'PY2' || fail "new install does not start with the widget layout"
import json, sys
d = json.load(open(sys.argv[1]))
assert "bundledBar" not in d
bar = d["barConfiguration"]
assert [c["widget"] for c in bar["components"]] == ["spaces", "network", "memory", "gpu", "cpu", "battery", "clock"]
assert [c["side"] for c in bar["components"]] == ["left"] + ["right"] * 6
assert bar["geometry"]["height"] == "35" and bar["geometry"]["sticky"] == "on"
assert bar["geometry"]["padding_left"] == "10" and bar["geometry"]["blur_radius"] == "0"
PY2
[ ! -e "$HOME_DIR/.config/macarchy" ] || fail "setup created an XDG launcher folder"
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
# they start from the launchers bundled in the app, whose paths have no space,
# and each hands over to Macarchy's file. The kept bar's items see
# ~/.config/sketchybar as $CONFIG_DIR.
YABAI_LAUNCHER="$RESOURCES/launchers/macarchy-yabairc"
LAUNCHER="$RESOURCES/launchers/macarchy-sketchybarrc"
[ "$(argument yabai 2)" = "$YABAI_LAUNCHER" ] || fail "yabai agent does not start from its launcher"
[ "$(argument sketchybar 2)" = "$LAUNCHER" ] || fail "SketchyBar agent does not start from its launcher"
grep -q '^exec "$TASK_HOME/Library/Application Support/Macarchy/config/yabairc" "$@"$' "$YABAI_LAUNCHER" \
  || fail "launcher does not hand over to Macarchy's yabairc"
grep -q '^exec "$TASK_HOME/Library/Application Support/Macarchy/config/sketchybarrc" "$@"$' "$LAUNCHER" \
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
[ -x "$YABAI_LAUNCHER" ] || fail "uninstall removed a bundled launcher"
[ -x "$LAUNCHER" ] || fail "uninstall removed a bundled launcher"
[ -e "$HOME_DIR/.config/macarchy" ] && fail "uninstall left the launcher folder"
[ -f "$SETTINGS" ] || fail "uninstall removed settings"

# A replaced setup starts from defaults and still leaves the person's files alone.
rm -rf "$CONFIG"
"$CLI" setup --replace --no-apply >/dev/null
untouched "replace"
grep -q '^ctrl - left : ' "$CONFIG/skhdrc" || fail "default shortcuts missing"
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

# Setup leaves Ghostty alone; the Plugins page themes it. An include an
# earlier version added is still taken out by uninstall.
rm -rf "$HOME_DIR/.config" "$CONFIG"
mkdir -p "$HOME_DIR/.config/ghostty"
echo 'font-size = 13' > "$HOME_DIR/.config/ghostty/config"
"$CLI" setup --replace --no-apply >/dev/null
grep -q '^ctrl - left : ' "$CONFIG/skhdrc" || fail "default shortcuts missing"
[ "$(cat "$HOME_DIR/.config/ghostty/config")" = 'font-size = 13' ] || fail "setup changed Ghostty's config"
[ -e "$ROOT/plugins" ] && fail "setup seeded plugins"
[ -e "$HOME_DIR/.zshenv" ] && fail "setup changed zsh's startup files"
printf '\n# Theme colours from Macarchy\nconfig-file = ?%s\n' "$ROOT/generated/ghostty.conf" \
  >> "$HOME_DIR/.config/ghostty/config"
"$CLI" uninstall >/dev/null
[ "$(cat "$HOME_DIR/.config/ghostty/config")" = 'font-size = 13' ] || fail "earlier Ghostty include not removed"
rm -rf "$HOME_DIR/.config" "$ROOT"

# An uninstall that stops part way says what it had already restored, and a
# second run finishes. Backups are restored in path order, so the installer's
# yabai agent comes back before Macarchy's, which cannot be removed.
rm -rf "$HOME_DIR/.config" "$CONFIG"
mkdir -p "$AGENTS"
echo 'installer agent' > "$AGENTS/com.asmvik.yabai.plist"
"$CLI" setup --replace --no-apply >/dev/null
chflags uchg "$AGENTS/io.github.harryrandall.macarchy.yabai.plist"
OUTPUT="$("$CLI" uninstall 2>&1)" && fail "uninstall past a locked agent succeeded"
chflags nouchg "$AGENTS/io.github.harryrandall.macarchy.yabai.plist"
# The snapshot taken before restoring copied the flag too.
chflags -R nouchg "$ROOT/snapshots"
grep -q 'Uninstall stopped part way' <<<"$OUTPUT" || fail "partial uninstall not reported: $OUTPUT"
grep -q 'Restored ~/Library/LaunchAgents/com.asmvik.yabai.plist' <<<"$OUTPUT" \
  || fail "restored files not listed: $OUTPUT"
# Handing yabai back to its installer's agent needs launchctl, which is not
# faked here, so only the files are checked.
OUTPUT="$("$CLI" uninstall 2>&1)" || true
grep -q 'Uninstall stopped part way' <<<"$OUTPUT" && fail "second uninstall did not finish: $OUTPUT"
grep -q 'Removed ~/Library/LaunchAgents/io.github.harryrandall.macarchy.yabai.plist' <<<"$OUTPUT" \
  || fail "second uninstall did not remove the locked agent: $OUTPUT"
[ "$(cat "$AGENTS/com.asmvik.yabai.plist")" = 'installer agent' ] || fail "installer agent not restored on retry"
for daemon in yabai skhd sketchybar borders; do
  [ -e "$AGENTS/io.github.harryrandall.macarchy.$daemon.plist" ] && fail "$daemon agent left after retry"
done

# A missing backup stops uninstall before anything changes.
"$CLI" setup --replace --no-apply >/dev/null
rm "$ROOT/backups/"*-com.asmvik.yabai.plist
"$CLI" uninstall >/dev/null 2>&1 && fail "uninstall succeeded with a missing backup"
[ "$(cat "$AGENTS/com.asmvik.yabai.plist")" = 'installer agent' ] || fail "file changed despite a missing backup"
[ -e "$AGENTS/io.github.harryrandall.macarchy.yabai.plist" ] || fail "agent removed despite a missing backup"
rm -rf "$ROOT/backups" "$AGENTS"

# A bar written for another interpreter no longer matters, since the bar is
# Macarchy's widgets: --keep leaves it as it is.
rm -rf "$HOME_DIR/.config" "$ROOT"
mkdir -p "$HOME_DIR/.config/sketchybar" "$HOME_DIR/.config/yabai"
printf '#!/usr/bin/env lua\nsbar = require("sketchybar")\n' > "$HOME_DIR/.config/sketchybar/sketchybarrc"
echo 'yabai -m config window_gap 4' > "$HOME_DIR/.config/yabai/yabairc"
"$CLI" setup --keep --no-apply >/dev/null || fail "a Lua sketchybarrc stopped setup"
grep -q 'require("sketchybar")' "$HOME_DIR/.config/sketchybar/sketchybarrc" || fail "Lua bar changed"
grep -q 'sbar' "$CONFIG/sketchybarrc" && fail "Lua bar adopted"
"$CLI" uninstall >/dev/null

# A yabairc written for another interpreter is not wrapped in bash: --keep
# stops before changing anything and says what to do.
rm -rf "$HOME_DIR/.config" "$ROOT"
mkdir -p "$HOME_DIR/.config/yabai"
printf '#!/bin/zsh\nyabai -m config window_gap 4\n' > "$HOME_DIR/.config/yabai/yabairc"
OUTPUT="$("$CLI" setup --keep --no-apply 2>&1)" && fail "setup kept a zsh yabairc"
grep -q 'runs with zsh' <<<"$OUTPUT" || fail "zsh refusal not explained: $OUTPUT"
grep -q 'some files may already have changed' <<<"$OUTPUT" && fail "refusal claims changes: $OUTPUT"
grep -q 'window_gap 4' "$HOME_DIR/.config/yabai/yabairc" || fail "yabairc changed by a refused setup"
[ -e "$ROOT/backups" ] && fail "refused setup wrote backups"
[ -e "$CONFIG" ] && fail "refused setup wrote configs"
printf '#!/bin/bash\nif then\n' > "$HOME_DIR/.config/yabai/yabairc"
"$CLI" setup --keep --no-apply >/dev/null 2>&1 && fail "setup kept a yabairc bash cannot parse"
"$CLI" setup --replace --no-apply >/dev/null || fail "replace refused a non-bash yabairc"
bash -n "$CONFIG/yabairc" || fail "replaced yabairc syntax"
grep -q 'if then' "$HOME_DIR/.config/yabai/yabairc" || fail "replace changed the person's yabairc"
"$CLI" uninstall >/dev/null

# Only the chosen tools are configured, each from its own config or the
# defaults, and the choice is remembered for the next setup.
rm -rf "$HOME_DIR/.config" "$ROOT"
mkdir -p "$HOME_DIR/.config/yabai" "$HOME_DIR/.config/skhd"
echo 'yabai -m config window_gap 21' > "$HOME_DIR/.config/yabai/yabairc"
echo 'cmd - k : echo kept' > "$HOME_DIR/.config/skhd/skhdrc"
[ "$(status "$CLI" setup --tools=yabai,dock)" = 2 ] || fail "unknown tool accepted"
[ "$(status "$CLI" setup --keep=skhd --replace=skhd)" = 2 ] || fail "a tool both kept and replaced"
[ -e "$ROOT/settings.json" ] && fail "a rejected setup changed files"
"$CLI" setup --tools=yabai,skhd --replace=skhd --no-apply >/dev/null
grep -q '"window_gap" : 21' "$SETTINGS" || fail "kept yabairc not adopted"
grep -q '^ctrl - left : ' "$CONFIG/skhdrc" || fail "replaced skhd did not start from defaults"
grep -q 'echo kept' "$CONFIG/skhdrc" && fail "replaced skhd kept the person's shortcuts"
for daemon in sketchybar borders; do
  [ -e "$AGENTS/io.github.harryrandall.macarchy.$daemon.plist" ] && fail "$daemon set up though left out"
  [ -e "$CONFIG/${daemon}rc" ] && fail "${daemon}rc written though $daemon was left out"
done
python3 - "$SETTINGS" <<'PY3' || fail "chosen tools not saved"
import json, sys
assert json.load(open(sys.argv[1]))["tools"] == ["yabai", "skhd"]
PY3
DOCTOR="$("$CLI" doctor 2>&1 || true)"
grep -q 'ok   SketchyBar: Left out of setup' <<<"$DOCTOR" || fail "doctor does not say SketchyBar is left alone: $DOCTOR"
grep -q 'SketchyBar agent' <<<"$DOCTOR" && fail "doctor checks SketchyBar though it is left out: $DOCTOR"
"$CLI" setup --keep --no-apply >/dev/null
[ -e "$AGENTS/io.github.harryrandall.macarchy.borders.plist" ] && fail "a later setup forgot the chosen tools"
"$CLI" uninstall >/dev/null

# --install installs chosen tools that are missing with Homebrew first, and
# uninstall --remove-tools removes only those. A fake brew installs a tool by
# putting a fake beside itself.
rm -rf "$HOME_DIR/.config" "$ROOT" "$AGENTS"
cp "$MACARCHY_SEARCH_PATH/brew" "$HOME_DIR/brew.saved"
cp "$MACARCHY_SEARCH_PATH/borders" "$HOME_DIR/borders.saved"
rm "$MACARCHY_SEARCH_PATH/borders"
cat > "$MACARCHY_SEARCH_PATH/brew" <<SH
#!/bin/sh
printf '%s\n' "brew \$*" >>'$CALLS'
name="\${2##*/}"
case "\$1" in
  install) echo "==> Pouring \$name"; cp '$HOME_DIR/borders.saved' "$MACARCHY_SEARCH_PATH/\$name" ;;
  uninstall) rm -f "$MACARCHY_SEARCH_PATH/\$name" ;;
esac
SH
chmod +x "$MACARCHY_SEARCH_PATH/brew"
OUTPUT="$("$CLI" setup --tools=yabai,borders --install --no-apply)" || fail "setup --install failed: $OUTPUT"
grep -q 'Installing borders with Homebrew' <<<"$OUTPUT" || fail "install not announced: $OUTPUT"
grep -q '  ==> Pouring borders' <<<"$OUTPUT" || fail "Homebrew's output not shown: $OUTPUT"
grep -q 'Installed borders with Homebrew' <<<"$OUTPUT" || fail "install not reported: $OUTPUT"
grep -q 'brew install.*yabai' "$CALLS" && fail "an installed tool was installed again"
[ -x "$MACARCHY_SEARCH_PATH/borders" ] || fail "borders not installed"
[ -e "$AGENTS/io.github.harryrandall.macarchy.borders.plist" ] || fail "installed borders not set up"
OUTPUT="$("$CLI" uninstall)"
grep -q 'macarchy uninstall --remove-tools' <<<"$OUTPUT" || fail "removing installed tools not offered: $OUTPUT"
[ -x "$MACARCHY_SEARCH_PATH/borders" ] || fail "uninstall removed a tool without --remove-tools"
OUTPUT="$("$CLI" uninstall --remove-tools)"
grep -q 'Removed borders with Homebrew' <<<"$OUTPUT" || fail "borders not removed: $OUTPUT"
[ -e "$MACARCHY_SEARCH_PATH/borders" ] && fail "borders still installed"
[ -x "$MACARCHY_SEARCH_PATH/yabai" ] || fail "uninstall removed a tool Macarchy did not install"
grep -q 'brew uninstall.*yabai' "$CALLS" && fail "a tool that was there before was removed"
mv "$HOME_DIR/brew.saved" "$MACARCHY_SEARCH_PATH/brew"
mv "$HOME_DIR/borders.saved" "$MACARCHY_SEARCH_PATH/borders"

# A full setup, apply and theme change in the temporary home reach only the
# fake tools. launchd and the global defaults the default borders' window
# corners use are reached only through a fake launchctl and defaults on the
# search path; the appearance, the wallpaper and running apps are refused
# (see DesktopIsolation), so the real desktop is left alone even though
# nothing here is a dry run.
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
cat > "$MACARCHY_SEARCH_PATH/defaults" <<SH
#!/bin/sh
printf '%s\n' "defaults \$*" >>'$CALLS'
SH
chmod +x "$MACARCHY_SEARCH_PATH/defaults"
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
grep -q '^yabai -m signal --add label=macarchy_refocus_space ' "$CALLS" || fail "yabai's startup file added no signals"
OUTPUT="$(run_agent sketchybar 2>&1)" || fail "SketchyBar did not run its startup file: $OUTPUT"
grep -q '^sketchybar --bar height=35 ' "$CALLS" || fail "SketchyBar's startup file set up no bar: $OUTPUT"
grep -q -- '--load-font .*/sketchybar/sketchybar-app-font.ttf' "$CALLS" || fail "the bar did not load the app font"
grep -q -- '--add item macarchy.clock right' "$CALLS" || fail "SketchyBar's startup file added no widgets"
# While no widget host runs, SketchyBar runs the clock's fallback itself; it
# leaves the clock alone while a host, such as the app, holds its lock.
grep -q "script=.* widget fallback 'macarchy.clock'" "$CALLS" || fail "the clock has no fallback"
: > "$CALLS"
"$CLI" widget fallback macarchy.clock || fail "the clock fallback failed"
grep -q -- '--set macarchy.clock .*label=' "$CALLS" || fail "the clock fallback did not update the clock"
: > "$CALLS"
lockf -t 0 "$ROOT/state/widget-host.lock" "$CLI" widget fallback macarchy.clock \
  || fail "the clock fallback failed while a host ran"
grep -q 'macarchy.clock' "$CALLS" && fail "the clock fallback ran while a host held the lock"
OUTPUT="$(run_agent borders 2>&1)" || fail "borders did not run its startup file: $OUTPUT"
grep -q '^borders .*active_color=' "$CALLS" || fail "bordersrc did not start borders: $OUTPUT"
DOCTOR="$("$CLI" doctor 2>&1 || true)"
grep -q 'has not run its startup file' <<<"$DOCTOR" && fail "doctor reports a startup file that ran: $DOCTOR"
grep -q 'agent: Macarchy' <<<"$DOCTOR" && fail "doctor reports a start file problem: $DOCTOR"
"$CLI" apply >/dev/null || fail "isolated apply failed"
grep -qx 'defaults write -g NSConvolutionOverride1 -float 0.3' "$CALLS" \
  || fail "apply did not set the default borders' window corners"
# A copied theme folder whose manifest still names the original is stepped over.
cp -R "$ROOT/themes/midnight" "$ROOT/themes/midnight-copy"
"$CLI" theme midnight >/dev/null || fail "isolated theme change failed"
"$CLI" theme next >/dev/null || fail "isolated theme change failed"
grep -q '"currentTheme" : "turbonite"' "$SETTINGS" || fail "theme next did not advance"
OUTPUT="$("$CLI" theme midnight-copy 2>&1)" && fail "mismatched theme folder applied"
grep -q 'folder midnight-copy contains the theme midnight' <<<"$OUTPUT" || fail "mismatch not explained: $OUTPUT"
grep -q 'may already have applied' <<<"$OUTPUT" && fail "untouched desktop reported as partly changed"
grep -q '^yabai -m config' "$CALLS" || fail "apply did not reach the fake yabai"
"$CLI" uninstall >/dev/null || fail "isolated uninstall failed"
rm "$MACARCHY_SEARCH_PATH/launchctl" "$MACARCHY_SEARCH_PATH/defaults"

# A Space click on the bar runs `macarchy space`, which still reaches a
# custom yabai whose path has a space in it. It asks which Spaces there are
# first, so a number with no Space is left alone.
BAR_BIN="$HOME_DIR/bar home/bin"
mkdir -p "$BAR_BIN"
cat > "$BAR_BIN/yabai" <<SH
#!/bin/sh
printf '%s\n' "yabai \$*" >>'$CALLS'
[ "\$*" = "-m query --spaces" ] && printf '[{"id":42,"index":1}]\n'
exit 0
SH
chmod +x "$BAR_BIN/yabai"
: > "$CALLS"
MACARCHY_SEARCH_PATH="$BAR_BIN" "$CLI" space 1 || fail "Space click failed"
grep -qx 'yabai -m space --focus 1' "$CALLS" || fail "Space click did not reach yabai: $(cat "$CALLS")"

echo "setup integration test passed"
