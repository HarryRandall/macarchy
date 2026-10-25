#!/bin/bash
# Upgrades a copy of a real earlier layout (tests/fixtures/upgrade) in a
# temporary home with fake daemons, never the installed desktop.
# Usage: tests/integration/upgrade.sh
#
# The fixture is an owner's ~/.config/macarchy from before the move to
# Application Support, with their settings, themes, a widget, snapshots and
# backups, an skhdrc whose shortcuts run the command through the old folder,
# startup files whose keep regions hold their own commands and bar, and the
# earlier borders agent. `@HOME@` stands for the home folder.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
swift build --package-path "$REPO" -c debug >/dev/null
CLI="$(swift build --package-path "$REPO" --show-bin-path)/macarchy"
FIXTURE="$REPO/tests/fixtures/upgrade/home"

WORK="$(mktemp -d -t macarchy-upgrade-test)"
trap 'rm -rf "$WORK"' EXIT
RESOURCES="$WORK/resources"
mkdir -p "$RESOURCES"
cp "$REPO/resources/app/logo.svg" "$RESOURCES/"
cp -R "$REPO/resources/themes" "$REPO/resources/integrations/sketchybar" \
  "$REPO/resources/integrations/skhd" "$RESOURCES/"
export MACARCHY_RESOURCES="$RESOURCES"

fail() { echo "FAIL: $*" >&2; exit 1; }
same_json() { python3 -c 'import json,sys; sys.exit(json.load(open(sys.argv[1])) != json.load(open(sys.argv[2])))' "$1" "$2"; }
# Succeeds when a snapshot record names a file in the old folder. The records
# are JSON, which escapes each slash, so they are decoded rather than searched.
records_old_folder() {
  python3 - "$OLD" "$@" <<'PY'
import json, sys
old = sys.argv[1]
paths = [p for f in sys.argv[2:] for p in json.load(open(f))["paths"].values()]
sys.exit(0 if any(p == old or p.startswith(old + "/") for p in paths) else 1)
PY
}

# A fresh copy of the earlier layout in its own home, with fake tools and
# the installed app (which holds this build's command and resources) linked
# from the old folder, as the earlier version left it.
make_home() {
  H="$WORK/$1"
  mkdir -p "$H"
  cp -R "$FIXTURE/." "$H/"
  grep -rlI '@HOME@' "$H" | while IFS= read -r file; do
    sed -i '' "s#@HOME@#$H#g" "$file"
  done
  export HOME="$H" MACARCHY_HOME="$H" MACARCHY_SEARCH_PATH="$H/fake-bin" MACARCHY_APPLICATIONS="$H/Applications"
  mkdir -p "$MACARCHY_SEARCH_PATH"
  CALLS="$H/calls.log"
  for tool in yabai skhd sketchybar borders brew launchctl; do
    cat > "$MACARCHY_SEARCH_PATH/$tool" <<SH
#!/bin/sh
printf '%s\n' "$tool \$*" >>'$CALLS'
case "\$*" in *--list*|*query*) echo '[]' ;; esac
case "$tool \$1" in "launchctl print") printf 'state = running\npid = 4242\n' ;; esac
exit 0
SH
    chmod +x "$MACARCHY_SEARCH_PATH/$tool"
  done
  APP="$H/Applications/Macarchy.app"
  mkdir -p "$APP/Contents/MacOS"
  cp "$CLI" "$APP/Contents/MacOS/macarchy"
  cp -R "$RESOURCES" "$APP/Contents/Resources"
  ln -s "$APP" "$H/.config/macarchy/Macarchy.app"
  OLD="$H/.config/macarchy"
  ROOT="$H/Library/Application Support/Macarchy"
  CONFIG="$ROOT/config"
}

# The bar the earlier version started keeps running its plugins through the
# old app link, which now leads to this build's scripts.
run_old_bar_plugin() {
  HOME="$H" PATH="/usr/bin:/bin" NAME=cpu \
    bash "$OLD/Macarchy.app/Contents/Resources/sketchybar/plugins/cpu.sh" >/dev/null 2>&1 || true
}

make_home owner
cp "$OLD/settings.json" "$WORK/settings.before"
cp -R "$H/.config/sketchybar" "$WORK/sketchybar.before"
run_old_bar_plugin
[ -e "$ROOT" ] && fail "the old bar's plugin created the new folder before migration"

# The first command after the upgrade moves the folder.
"$CLI" doctor >/dev/null 2>&1 || true
[ -L "$OLD" ] || fail "no link left at the old folder"
same_json "$WORK/settings.before" "$ROOT/settings.json" || fail "settings changed by the move"
for theme in lumon midnight; do
  [ -f "$ROOT/themes/$theme/theme.json" ] || fail "theme $theme not carried"
done
[ -f "$ROOT/widgets/owner-clock/widget.json" ] || fail "widget not carried"
[ "$(find "$ROOT/snapshots" -name .meta.json | wc -l | tr -d ' ')" = 2 ] || fail "snapshots not carried"
records_old_folder "$ROOT/snapshots"/*/.meta.json && fail "a snapshot still records the old folder"
# The check can fail: the record kept from before the move names the old folder.
records_old_folder "$ROOT/snapshots"/*/.meta.legacy.json \
  || fail "the snapshot check cannot see the old folder in a record"

OUTPUT="$("$CLI" setup --no-apply 2>&1)" || fail "setup failed: $OUTPUT"
same_json "$WORK/settings.before" "$ROOT/settings.json" || fail "setup changed settings: $OUTPUT"
python3 - "$ROOT/settings.json" <<'PY' || fail "owner's settings lost"
import json, sys
d = json.load(open(sys.argv[1]))
assert d["currentTheme"] == "lumon", d["currentTheme"]
assert d["bundledBar"] is False
assert d["borders"]["border_width"] == 7
assert d["menuBar"]["height"] == 35 and d["itemOrder"] == []
assert d["barConfiguration"]["components"][0]["id"] == "workspaces"
PY
grep -q 'Kept your menu bar' <<<"$OUTPUT" || fail "own bar not reported: $OUTPUT"
grep -q 'Carried your own commands over from ~/.config/yabai/yabairc' <<<"$OUTPUT" \
  || fail "yabai region not reported: $OUTPUT"
grep -q 'Pointed 4 paths from ~/.config/skhd/skhdrc' <<<"$OUTPUT" \
  || fail "rewritten shortcuts not reported: $OUTPUT"

# Keep regions carry across; the owner's own bar still runs before startup.
grep -q '^sudo yabai --load-sa$' "$CONFIG/yabairc" || fail "yabai keep region lost"
grep -q 'label=restart_borders' "$CONFIG/yabairc" || fail "yabai keep region cut short"
grep -q 'source "$CONFIG_DIR/colors.sh"' "$CONFIG/sketchybarrc" || fail "bar keep region lost"
[ "$(grep -n 'source "$ITEM_DIR/spaces.sh"' "$CONFIG/sketchybarrc" | cut -d: -f1)" -lt \
  "$(grep -n 'startup sketchybar' "$CONFIG/sketchybarrc" | cut -d: -f1)" ] || fail "own bar must run before startup"
for rc in yabairc sketchybarrc bordersrc; do
  bash -n "$CONFIG/$rc" || fail "$rc syntax"
  grep -q '.config/macarchy' "$CONFIG/$rc" && fail "$rc still reaches the old folder"
done
grep -q 'theme_listener' "$CONFIG/sketchybarrc" || fail "bar region cut short"

# Every shortcut that runs the command reaches an existing one, the
# rewritten ones directly and anything else through the link.
grep -q '.config/macarchy' "$CONFIG/skhdrc" && fail "shortcuts still name the old folder"
[ "$(grep -c '"$HOME/Library/Application Support/Macarchy/Macarchy.app/Contents/MacOS/macarchy"' "$CONFIG/skhdrc")" = 4 ] \
  || fail "old command paths not rewritten"
grep -o '"$HOME/[^"]*macarchy"' "$CONFIG/skhdrc" | sort -u | while IFS= read -r quoted; do
  path="${quoted//\"/}"
  [ -x "${path/\$HOME/$H}" ] || fail "shortcut command $path does not exist"
done
[ -L "$OLD" ] || fail "setup removed the link scripts outside Macarchy still use"
[ -x "$OLD/Macarchy.app/Contents/MacOS/macarchy" ] || fail "the old command path no longer resolves"
# The fixture leaves out the owner's wallpaper images; stand-ins let a theme change run.
python3 - "$ROOT" <<'PY'
import json, os, sys
root = sys.argv[1]
for theme, image in json.load(open(os.path.join(root, "settings.json")))["wallpapers"].items():
    path = os.path.join(root, "themes", theme, image)
    if os.path.isdir(os.path.join(root, "themes", theme)):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        open(path, "a").close()
PY
command="$(grep '^cmd + ctrl - 0x18 :' "$CONFIG/skhdrc" | sed 's/^[^:]*: //')"
OUTPUT="$(HOME="$H" sh -c "$command" 2>&1)" || fail "theme shortcut failed: $command: $OUTPUT"
grep -q '"currentTheme" : "lumon"' "$ROOT/settings.json" && fail "theme shortcut did nothing"

# The owner's own bar runs as it did before. SketchyBar sets $CONFIG_DIR and
# its working folder to the folder of the file its agent names, links
# resolved, and passes both to every item script; this runs the bar and the
# owner's scripts the same way, with fakes first on PATH and every tool the
# scripts name by full path pointed at a fake.
AGENTS="$H/Library/LaunchAgents"
START="$(plutil -extract ProgramArguments.2 raw "$AGENTS/io.github.harryrandall.macarchy.sketchybar.plist")"
BAR_FOLDER="$(dirname "$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$START")")"
[ "$BAR_FOLDER" = "$(cd "$H/.config/sketchybar" && pwd -P)" ] \
  || fail "SketchyBar would give the owner's items $BAR_FOLDER as CONFIG_DIR"
grep -q 'Written by Macarchy' "$START" || fail "SketchyBar does not start from Macarchy's launcher"
rm -rf "$WORK/sketchybar.after"; cp -R "$H/.config/sketchybar" "$WORK/sketchybar.after"
rm "$WORK/sketchybar.after/macarchy-sketchybarrc"
diff -r "$WORK/sketchybar.before" "$WORK/sketchybar.after" >/dev/null || fail "setup changed the owner's bar folder"
echo '{}' > "$WORK/macmon.json"
as_sketchybar() {
  (cd "$BAR_FOLDER" && env HOME="$H" CONFIG_DIR="$BAR_FOLDER" PATH="$MACARCHY_SEARCH_PATH:/usr/bin:/bin" \
    SKETCHYBAR_BIN="$MACARCHY_SEARCH_PATH/sketchybar" YABAI_BIN="$MACARCHY_SEARCH_PATH/yabai" \
    JQ_BIN="$MACARCHY_SEARCH_PATH/jq" MACMON_DATA_FILE="$WORK/macmon.json" "$@")
}
printf '#!/bin/sh\nexit 0\n' > "$MACARCHY_SEARCH_PATH/jq"; chmod +x "$MACARCHY_SEARCH_PATH/jq"
: > "$CALLS"
OUTPUT="$(as_sketchybar "$START" 2>&1)" || fail "the bar did not start: $OUTPUT"
grep -q 'No such file' <<<"$OUTPUT" && fail "the bar could not find its files: $OUTPUT"
grep -q "script=$BAR_FOLDER/plugins/battery.sh" "$CALLS" || fail "items not added with the owner's plugins"
for icon in $(grep -o "background.image=[^ ]*" "$CALLS" | cut -d= -f2 | sort -u); do
  [ -f "$icon" ] || fail "icon $icon missing"
done
grep -q "background.image=$BAR_FOLDER/icons/cpu.png" "$CALLS" || fail "icons not found through CONFIG_DIR"
grep -q 'sketchybar --add event macarchy_theme_changed' "$CALLS" || fail "the bar stopped before its theme listener"
[ -d "$BAR_FOLDER/.state" ] || fail "the owner's Space renderer kept no state"
# Item scripts as SketchyBar runs them later: colours come from the theme
# Macarchy wrote, read through the owner's colors.sh and the old-folder link.
TEXT="$(sed -n 's/^export TEXT_COLOR="\(.*\)"$/\1/p' "$ROOT/generated/bar-colours.sh")"
[ -n "$TEXT" ] || fail "no theme colours written"
: > "$CALLS"
as_sketchybar env NAME=battery SENDER=routine "$BAR_FOLDER/plugins/battery.sh" >/dev/null 2>&1
grep -q '^sketchybar --set battery' "$CALLS" || fail "battery plugin did not run"
as_sketchybar env NAME=ram.text SENDER=routine "$BAR_FOLDER/plugins/system_metrics.sh" >/dev/null 2>&1
grep -q -- '--set ram.text' "$CALLS" || fail "metrics plugin did not run"
: > "$CALLS"
as_sketchybar env SENDER=macarchy_theme_changed "$BAR_FOLDER/recolor.sh" >/dev/null 2>&1 || fail "recolor failed"
grep -q "label.color=$TEXT" "$CALLS" || fail "recolor did not use the theme's colours"
# Macarchy's own bar scripts, reached through the app link, keep their state in the new folder.
as_sketchybar env NAME=cpu "$ROOT/Macarchy.app/Contents/Resources/sketchybar/plugins/cpu.sh" >/dev/null 2>&1
[ -d "$ROOT/state/bar" ] || fail "Macarchy's bar scripts keep no state in the new folder"

# The earlier borders agent becomes Macarchy's, and is not recorded as an original.
plutil -extract ProgramArguments.0 raw "$H/Library/LaunchAgents/io.github.harryrandall.macarchy.borders.plist" \
  | grep -qx "$CONFIG/bordersrc" || fail "borders agent does not run Macarchy's bordersrc"
python3 - "$ROOT/backups/manifest.json" "$H" <<'PY' || fail "borders agent recorded as an original"
import json, sys
entries = json.load(open(sys.argv[1]))["entries"]
assert "absent" in entries[sys.argv[2] + "/Library/LaunchAgents/io.github.harryrandall.macarchy.borders.plist"]
PY

# Snapshots from before the upgrade restore into the new folder.
SETTINGS_SNAPSHOT=2026-10-24T02-55-36-959-1792810536961304064-47AF21A7-5ED0-4062-B42C-B127BC32B961
SHORTCUTS_SNAPSHOT=2026-10-24T03-10-00-000-1792811400000000000-0D6E3C1A-5B7E-4E43-9A2C-3F1D2A9B8C70
OUTPUT="$("$CLI" restore "$SETTINGS_SNAPSHOT" 2>&1)" || fail "restore failed: $OUTPUT"
same_json "$ROOT/snapshots/$SETTINGS_SNAPSHOT/0-settings.json" "$ROOT/settings.json" \
  || fail "old settings snapshot did not restore: $OUTPUT"
grep -q 'Restored ~/Library/Application Support/Macarchy/settings.json' <<<"$OUTPUT" \
  || fail "restore did not say what it restored: $OUTPUT"
[ -L "$OLD" ] || fail "restore recreated the old folder"
OUTPUT="$("$CLI" restore "$SHORTCUTS_SNAPSHOT" 2>&1)" || fail "restore failed: $OUTPUT"
cmp -s "$ROOT/snapshots/$SHORTCUTS_SNAPSHOT/0-skhdrc" "$CONFIG/skhdrc" \
  || fail "old shortcuts snapshot did not restore: $OUTPUT"
[ -e "$H/.config/skhd/skhdrc.macarchy-restore" ] && fail "restore staged in the old place"

DOCTOR="$("$CLI" doctor 2>&1 || true)"
grep -q 'Set up before Macarchy moved' <<<"$DOCTOR" && fail "doctor asks for setup again: $DOCTOR"
grep -q 'Earlier settings' <<<"$DOCTOR" && fail "doctor flags the moved folder: $DOCTOR"

OUTPUT="$("$CLI" uninstall 2>&1)" || fail "uninstall failed: $OUTPUT"
[ -e "$OLD" ] && fail "uninstall left the old folder link"
[ -e "$H/.config/sketchybar/macarchy-sketchybarrc" ] && fail "uninstall left the bar launcher"
grep -q 'before Macarchy' "$H/.config/yabai/yabairc" || fail "uninstall did not restore the original yabairc"
same_json "$ROOT/snapshots/$SETTINGS_SNAPSHOT/0-settings.json" "$ROOT/settings.json" || fail "uninstall changed settings"

# Something that ran first created the new folder: its files merge in, and
# only clashing files outside scratch state are kept aside, and reported.
make_home precreated
mkdir -p "$ROOT/state/bar" "$ROOT/generated"
echo 'scratch' > "$ROOT/state/bar/space_render"
echo 'made first' > "$ROOT/generated/extra"
"$CLI" doctor >/dev/null 2>&1 || true
same_json "$OLD/settings.json" "$ROOT/settings.json" || fail "settings lost when the folder existed first"
[ -f "$ROOT/themes/lumon/theme.json" ] || fail "themes lost when the folder existed first"
[ "$(cat "$ROOT/generated/extra")" = 'made first' ] || fail "early file not merged"
ls "$ROOT/.." | grep -q 'Macarchy before migration' && fail "a set-aside folder of scratch state was kept"

make_home clash
mkdir -p "$ROOT/generated"
echo 'other colours' > "$ROOT/generated/bar-colours.sh"
"$CLI" setup --no-apply >/dev/null 2>&1 || fail "setup failed after a clash"
same_json "$WORK/settings.before" "$ROOT/settings.json" || fail "settings lost after a clash"
ASIDE="$(ls -d "$ROOT/../Macarchy before migration"* 2>/dev/null | head -1)"
[ "$(cat "$ASIDE/generated/bar-colours.sh")" = 'other colours' ] || fail "clashing file not kept aside"
DOCTOR="$("$CLI" doctor 2>&1 || true)"
grep -q 'holds files that clashed' <<<"$DOCTOR" || fail "doctor does not report set-aside files: $DOCTOR"

# An earlier build that set up afresh left the old folder full: Doctor says so.
make_home leftover
mkdir -p "$ROOT"
echo '{"schema":1,"currentTheme":"midnight"}' > "$ROOT/settings.json"
DOCTOR="$("$CLI" doctor 2>&1 || true)"
grep -q 'still holds settings from an earlier version' <<<"$DOCTOR" \
  || fail "doctor does not report the old folder's settings: $DOCTOR"
[ -d "$OLD" ] && [ ! -L "$OLD" ] || fail "the old folder was moved over existing settings"

echo "upgrade integration test passed"
