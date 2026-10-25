#!/bin/bash
# Cleans up an owner's old configuration in a temporary home with fake
# daemons, never the installed desktop.
# Usage: tests/integration/cleanup.sh
#
# The home is the earlier layout in tests/fixtures/upgrade, upgraded as the
# owner's was (the folder moved, a link left at ~/.config/macarchy, setup run
# again), with tests/fixtures/cleanup on top: the owner's own scripts in
# ~/.config/yabai that their shortcuts run, old copies of their shortcuts,
# and the zsh and Neovim lines an earlier version wrote, which read through
# the link. `@HOME@` stands for the home folder.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
swift build --package-path "$REPO" -c debug >/dev/null
CLI="$(swift build --package-path "$REPO" --show-bin-path)/macarchy"

WORK="$(mktemp -d -t macarchy-cleanup-test)"
trap 'rm -rf "$WORK"' EXIT
RESOURCES="$WORK/resources"
mkdir -p "$RESOURCES"
cp "$REPO/resources/app/logo.svg" "$RESOURCES/"
cp -R "$REPO/resources/themes" "$REPO/resources/integrations/sketchybar" \
  "$REPO/resources/integrations/skhd" "$RESOURCES/"
export MACARCHY_RESOURCES="$RESOURCES"

fail() { echo "FAIL: $*" >&2; exit 1; }

# A home upgraded as the owner's was, with fake tools that run their start
# file as the real ones do: `sh -c <path>` unquoted, SketchyBar after
# resolving links and moving to the file's folder.
make_home() {
  H="$WORK/$1"
  mkdir -p "$H"
  cp -R "$REPO/tests/fixtures/upgrade/home/." "$H/"
  cp -R "$REPO/tests/fixtures/cleanup/home/." "$H/"
  mkdir -p "$H/.config/yabai/examples"
  # Git keeps only whether a file is executable; the owner's state file is private.
  chmod 600 "$H/.config/yabai/float_state.json"
  grep -rlI '@HOME@' "$H" | while IFS= read -r file; do
    sed -i '' "s#@HOME@#$H#g" "$file"
  done
  export HOME="$H" MACARCHY_HOME="$H" MACARCHY_SEARCH_PATH="$H/fake-bin" MACARCHY_APPLICATIONS="$H/Applications"
  mkdir -p "$MACARCHY_SEARCH_PATH"
  CALLS="$H/calls.log"
  for tool in yabai skhd sketchybar borders brew launchctl sudo jq; do
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
case "\$*" in *--list*|*query*) echo '[]' ;; esac
# Only Macarchy's jobs are loaded, so a failed start has nothing to fall back to.
case "$tool \$1 \$2" in
  "launchctl print "*io.github.harryrandall.macarchy.*) printf 'state = running\npid = 4242\n' ;;
  "launchctl print "*) exit 113 ;;
esac
exit 0
SH
    chmod +x "$MACARCHY_SEARCH_PATH/$tool"
  done
  APP="$H/Applications/Macarchy.app"
  mkdir -p "$APP/Contents/MacOS"
  cp "$CLI" "$APP/Contents/MacOS/macarchy"
  cp -R "$RESOURCES" "$APP/Contents/Resources"
  ln -s "$APP" "$H/.config/macarchy/Macarchy.app"
  LINK="$H/.config/macarchy"
  ROOT="$H/Library/Application Support/Macarchy"
  CONFIG="$ROOT/config"
  "$CLI" doctor >/dev/null 2>&1 || true
  "$CLI" setup --no-apply >/dev/null 2>&1 || fail "setup failed"
  # Started once, as on the owner's Mac, which retires the installers' agents.
  # skhd may not start while the session holds Secure Keyboard Entry.
  "$CLI" services >/dev/null 2>&1 || true
  [ -L "$LINK" ] || fail "no link left at ~/.config/macarchy"
}

# Every file under the home that cleaning up may touch, with its type,
# permissions and contents or link target, links not followed. Logs, the
# fake daemons' calls, snapshots, backups and scratch state are left out:
# cleaning up and restoring add to them.
tree() {
  python3 - "$H" <<'PY'
import hashlib, os, stat, sys
home = sys.argv[1]
skip = ("calls.log", "fake-bin", "Library/Application Support/Macarchy/snapshots",
        "Library/Application Support/Macarchy/backups", "Library/Application Support/Macarchy/state",
        "Library/Application Support/Macarchy/generated.json")
for folder, dirs, files in os.walk(home):
    for name in sorted(dirs + files):
        path = os.path.join(folder, name)
        rel = os.path.relpath(path, home)
        if rel.startswith(skip):
            continue
        info = os.lstat(path)
        if stat.S_ISLNK(info.st_mode):
            print(rel, "link", os.readlink(path))
        elif stat.S_ISDIR(info.st_mode):
            print(rel, "folder", oct(info.st_mode & 0o777))
        else:
            print(rel, oct(info.st_mode & 0o777), hashlib.sha256(open(path, "rb").read()).hexdigest())
    dirs[:] = [d for d in dirs if not os.path.islink(os.path.join(folder, d))]
PY
}

# Starts a daemon as launchd does: its agent's arguments, run directly with
# the agent's PATH and no shell in between.
run_agent() {
  local plist="$H/Library/LaunchAgents/io.github.harryrandall.macarchy.$1.plist" index=0 argument
  local arguments=()
  while argument="$(plutil -extract "ProgramArguments.$index" raw "$plist" 2>/dev/null)"; do
    arguments+=("$argument")
    index=$((index + 1))
  done
  env HOME="$H" PATH="$(plutil -extract EnvironmentVariables.PATH raw "$plist")" "${arguments[@]}"
}

# Every quoted path under the home that a shortcut runs exists, and is
# executable when the shortcut runs it directly.
check_shortcuts() {
  python3 - "$CONFIG/skhdrc" "$H" <<'PY'
import os, re, sys
text, home = open(sys.argv[1]).read(), sys.argv[2]
bad = []
for match in re.finditer(r'(/bin/bash )?"\$HOME(/[^"]*)"', text):
    path = home + match.group(2)
    if not os.path.exists(path) or (not match.group(1) and not os.access(path, os.X_OK)):
        bad.append(match.group(0))
print("\n".join(bad))
sys.exit(1 if bad else 0)
PY
}

make_home owner
BEFORE="$(tree)"
DOCTOR="$("$CLI" doctor 2>&1 || true)"
grep -q 'warn Old configuration: Can be cleaned up: 6 scripts to move' <<<"$DOCTOR" \
  || fail "doctor does not offer the cleanup: $DOCTOR"

# The dry run lists the plan and changes nothing.
PLAN="$("$CLI" cleanup)" || fail "dry run failed: $PLAN"
[ "$(tree)" = "$BEFORE" ] || fail "the dry run changed files"
for script in launch_ghostty quit_focused_window close_firefox_selector toggle_sketchybar_visibility \
  switch_space_native swap_space_and_refresh; do
  grep -qx "  ~/.config/yabai/$script.sh" <<<"$PLAN" || fail "plan does not move $script: $PLAN"
done
grep -qx '  ~/.config/skhd' <<<"$PLAN" || fail "plan does not delete the old shortcuts folder: $PLAN"
grep -qx '  ~/.config/borders' <<<"$PLAN" || fail "plan does not delete the old borders folder: $PLAN"
grep -qx '  ~/.config/zsh/.zshrc' <<<"$PLAN" || fail "plan does not point the zsh line: $PLAN"
grep -qx '  ~/.config/nvim/lua/config/theme.lua' <<<"$PLAN" || fail "plan does not point the Neovim line: $PLAN"
grep -q 'Make ~/.config/macarchy a folder for Macarchy' <<<"$PLAN" || fail "plan keeps the link: $PLAN"
grep -qx '  ~/.config/yabai/space_cycle.sh' <<<"$PLAN" || fail "plan does not leave an unused script: $PLAN"
grep -qx '  ~/.config/sketchybar' <<<"$PLAN" || fail "plan does not delete the old bar: $PLAN"
grep -q 'Nothing was changed' <<<"$PLAN" || fail "dry run does not say nothing changed"

# skhd's restart reads the real Secure Keyboard Entry state, which a locked
# screen holds; that is the only failure allowed.
apply() {
  OUTPUT="$("$CLI" cleanup --apply 2>&1)" || grep -q 'Secure Keyboard Entry is on' <<<"$OUTPUT" \
    || fail "cleanup failed: $OUTPUT"
}
apply
ARCHIVE="$(sed -n 's/.*macarchy cleanup --restore \(old-configuration-[0-9-]*\.zip\)$/\1/p' <<<"$OUTPUT" | head -1)"
[ -n "$ARCHIVE" ] && [ -f "$ROOT/backups/$ARCHIVE" ] || fail "no archive reported: $OUTPUT"
grep -q 'manifest.json' <<<"$(unzip -l "$ROOT/backups/$ARCHIVE")" || fail "the archive has no manifest"

# Scripts moved with their names and permissions, and every shortcut and
# moved script points at them.
for script in launch_ghostty quit_focused_window close_firefox_selector toggle_sketchybar_visibility \
  switch_space_native swap_space_and_refresh; do
  [ -x "$ROOT/scripts/$script.sh" ] || fail "$script.sh not moved, or not executable"
  [ -e "$H/.config/yabai/$script.sh" ] && fail "$script.sh left behind as well"
done
grep -q '.config/yabai\|.config/macarchy' "$CONFIG/skhdrc" && fail "shortcuts still name the old places"
check_shortcuts || fail "a shortcut runs something that is not there"
grep -c '"$HOME/Library/Application Support/Macarchy/scripts/' "$CONFIG/skhdrc" | grep -qx 54 \
  || fail "not every shortcut was pointed at the scripts folder"
bash -n "$CONFIG/yabairc" || fail "yabairc no longer parses"
# The owner's scripts name Homebrew's yabai in full, so they are checked,
# never run: running one would drive the real desktop.
for script in "$ROOT"/scripts/*; do bash -n "$script" || fail "$script no longer parses"; done

# Unused scripts and what they use stay.
for file in space_cycle.sh switch_space_macos27.sh sync_float_rules.sh toggle_float_persist.sh \
  apply_float_state.sh float_state.json; do
  [ -e "$H/.config/yabai/$file" ] || fail "$file was removed although nothing moved it"
done
[ "$(stat -f %Lp "$H/.config/yabai/float_state.json")" = 600 ] || fail "permissions changed"
for gone in yabairc macarchy-yabairc examples swap_space_and_refresh.sh.backup-20260919-170619 \
  swap_space_serial.py.retired-20260919 switch_space_native.sh.before-macarchy-space; do
  [ -e "$H/.config/yabai/$gone" ] && fail "$gone was not deleted"
done
[ -e "$H/.config/skhd" ] && fail "the old shortcuts folder was not deleted"
[ -e "$H/.config/borders" ] && fail "the old borders folder was not deleted"
[ -e "$H/.config/sketchybar" ] && fail "the old bar was not deleted"

# The launcher folder is real and holds only the launchers, which the
# daemons run through sh as the real ones do.
[ -d "$LINK" ] && [ ! -L "$LINK" ] || fail "~/.config/macarchy is still a link"
[ "$(ls -A "$LINK" | tr '\n' ' ')" = "macarchy-sketchybarrc macarchy-yabairc " ] \
  || fail "the launcher folder does not hold just the launchers: $(ls -A "$LINK")"
YABAI_START="$(plutil -extract ProgramArguments.2 raw "$H/Library/LaunchAgents/io.github.harryrandall.macarchy.yabai.plist")"
[ "$YABAI_START" = "$LINK/macarchy-yabairc" ] || fail "yabai does not start from the launcher folder: $YABAI_START"
BAR_START="$(plutil -extract ProgramArguments.2 raw "$H/Library/LaunchAgents/io.github.harryrandall.macarchy.sketchybar.plist")"
[ "$BAR_START" = "$LINK/macarchy-sketchybarrc" ] || fail "the bar does not start from the launcher folder: $BAR_START"
: > "$CALLS"
OUTPUT="$(run_agent yabai 2>&1)" || fail "yabai did not run its startup file: $OUTPUT"
grep -q '^yabai -m config layout ' "$CALLS" || fail "yabai's startup file did not apply the layout: $OUTPUT"
grep -qx 'sudo yabai --load-sa' "$CALLS" || fail "the owner's yabai region did not run: $OUTPUT"
: > "$CALLS"
OUTPUT="$(run_agent sketchybar 2>&1)" || fail "the bar did not run its startup file: $OUTPUT"
grep -q '^sketchybar --update' "$CALLS" || fail "the bar's startup file did not run: $OUTPUT"

# zsh and Neovim read the new folder.
VALUE="$(HOME="$H" zsh -fc "$(grep '^_MACARCHY_SHELL_ENV=' "$H/.config/zsh/.zshrc"); print -r -- \$_MACARCHY_SHELL_ENV")"
[ "$VALUE" = "$ROOT/generated/shell-env" ] || fail "zsh reads $VALUE"
[ -r "$VALUE" ] || fail "zsh's colours file is missing"
grep -qxF 'M.state_file = vim.fn.expand("~/Library/Application Support/Macarchy/generated/nvim-colorscheme")' \
  "$H/.config/nvim/lua/config/theme.lua" || fail "Neovim does not read the new folder"
if command -v nvim >/dev/null; then
  NAME="$(HOME="$H" XDG_CONFIG_HOME="$H/.config" nvim --clean --headless -u NONE \
    -c "lua package.path='$H/.config/nvim/lua/?.lua;'..package.path; io.write(require('config.theme').colorscheme())" \
    -c q 2>&1)"
  [ "$NAME" = "$(cat "$ROOT/generated/nvim-colorscheme")" ] || fail "Neovim read $NAME, not the theme's colourscheme"
fi

DOCTOR="$("$CLI" doctor 2>&1 || true)"
grep -q 'Old configuration' <<<"$DOCTOR" && fail "doctor still offers a cleanup: $DOCTOR"
grep -q 'FAIL .* agent' <<<"$DOCTOR" && fail "doctor reports an agent problem: $DOCTOR"
grep -q 'FAIL .*rc' <<<"$DOCTOR" && fail "doctor reports a startup file problem: $DOCTOR"
OUTPUT="$("$CLI" cleanup)"
grep -q '^Nothing to clean up' <<<"$OUTPUT" || fail "a second cleanup still has work: $OUTPUT"

# Restoring the archive puts every file back as it was.
OUTPUT="$("$CLI" cleanup --restore "$ARCHIVE" 2>&1)" || grep -q 'Secure Keyboard Entry is on' <<<"$OUTPUT" \
  || fail "restore failed: $OUTPUT"
AFTER="$(tree)"
[ "$AFTER" = "$BEFORE" ] || fail "restore did not put everything back: $(diff <(echo "$BEFORE") <(echo "$AFTER"))"
[ "$(plutil -extract ProgramArguments.2 raw "$H/Library/LaunchAgents/io.github.harryrandall.macarchy.yabai.plist")" \
  = "$H/.config/yabai/macarchy-yabairc" ] || fail "yabai's agent does not start from its old launcher again"
DOCTOR="$("$CLI" doctor 2>&1 || true)"
grep -q 'warn Old configuration' <<<"$DOCTOR" || fail "doctor does not offer the cleanup again: $DOCTOR"

# A region of Macarchy's sketchybarrc that still reads $CONFIG_DIR keeps
# the old bar folder, and the bar's launcher in it, since SketchyBar gives
# that variable the launcher's folder.
make_home bar
python3 - "$CONFIG/sketchybarrc" <<'PY'
import sys
path = sys.argv[1]
text = open(path).read().replace(
    "# >>> macarchy:keep yours\n", '# >>> macarchy:keep yours\nsource "$CONFIG_DIR/colors.sh"\n')
open(path, "w").write(text)
PY
OUTPUT="$("$CLI" cleanup)"
grep -q 'reads it through \$CONFIG_DIR' <<<"$OUTPUT" || fail "plan does not keep the bar folder: $OUTPUT"
apply
[ -f "$H/.config/sketchybar/colors.sh" ] || fail "the bar folder its region reads was deleted"
grep -q '.config/macarchy' "$H/.config/sketchybar/colors.sh" && fail "the bar's colours still read through the link"
[ -f "$H/.config/sketchybar/macarchy-sketchybarrc" ] || fail "the bar's launcher left its folder"
[ "$(ls -A "$LINK")" = macarchy-yabairc ] || fail "the launcher folder: $(ls -A "$LINK")"

# A link at ~/.config/macarchy that something cleanup cannot change still
# reads through stays, and so do the launchers.
make_home vim
echo 'source ~/.config/macarchy/generated/shell-env' > "$H/.config/nvim/init.vim"
OUTPUT="$("$CLI" cleanup)"
grep -q 'init.vim still reads through this link' <<<"$OUTPUT" || fail "plan does not keep the link Vim script reads: $OUTPUT"
grep -q 'Make ~/.config/macarchy' <<<"$OUTPUT" && fail "plan replaces a link something still reads: $OUTPUT"
apply
[ -L "$LINK" ] || fail "the link Vim script reads was replaced"
[ -f "$H/.config/yabai/macarchy-yabairc" ] || fail "the yabai launcher moved into a link"

echo "cleanup integration test passed"
