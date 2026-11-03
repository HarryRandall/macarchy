#!/bin/bash
# Move existing Neovim files into managed storage, preserving conflicting copies.
set -euo pipefail
TASK_HOME="${MACARCHY_HOME:-$HOME}"
ROOT="$TASK_HOME/Library/Application Support/Macarchy"
PLUGIN="$ROOT/plugins/neovim"
BACKUP="$ROOT/backups/plugins-$(date +%Y%m%d-%H%M%S)-$$"
GHOSTTY_XDG="$TASK_HOME/.config/ghostty"
GHOSTTY_NATIVE="$TASK_HOME/Library/Application Support/com.mitchellh.ghostty"
# Check every source before moving anything, so a refusal leaves no half move.
for source in .config/nvim .local/share/nvim .local/state/nvim .cache/nvim .config/ghostty; do
  if [ -L "$TASK_HOME/$source" ]; then
    echo "Refusing to move a linked folder: $TASK_HOME/$source. Move its contents explicitly." >&2
    exit 1
  fi
done
move_folder() {
  local source="$1" destination="$2"
  [ -e "$source" ] || return 0
  mkdir -p "$(dirname "$destination")"
  if [ -e "$destination" ] || [ -L "$destination" ]; then
    mkdir -p "$BACKUP"
    mv "$destination" "$BACKUP/$(basename "$(dirname "$destination")")-$(basename "$destination")"
  fi
  mv "$source" "$destination"
  echo "Moved $source to $destination"
}
move_folder "$TASK_HOME/.config/nvim" "$PLUGIN/config/nvim"
move_folder "$TASK_HOME/.local/share/nvim" "$PLUGIN/data/nvim"
move_folder "$TASK_HOME/.local/state/nvim" "$PLUGIN/state/nvim"
move_folder "$TASK_HOME/.cache/nvim" "$PLUGIN/cache/nvim"
# Treesitter links and Mason launchers can contain the old absolute data path.
# The new one has a space, which a #! line cannot hold, so a Python script
# gets pip's /bin/sh trampoline and any other interpreter is reported.
/usr/bin/python3 - "$TASK_HOME" "$PLUGIN" <<'PYTHON'
from pathlib import Path
import os, sys
home, plugin = map(Path, sys.argv[1:])
old = str(home / '.local/share/nvim').encode()
new = str(plugin / 'data/nvim').encode()
root = plugin / 'data/nvim'
links = 0
for path in root.rglob('*'):
    if not path.is_symlink():
        continue
    target = os.readlink(path).encode()
    if target == old or target.startswith(old + b'/'):
        path.unlink()
        path.symlink_to((new + target[len(old):]).decode())
        links += 1
files = 0
unfixed = []
for path in (root / 'mason').rglob('*'):
    if path.is_symlink() or not path.is_file() or path.stat().st_size > 1048576:
        continue
    if not os.access(path, os.X_OK):
        continue
    data = path.read_bytes()
    if not data.startswith(b'#!') or old not in data:
        continue
    first, newline, rest = data.partition(b'\n')
    if old in first:
        interpreter = first[2:].strip()
        if b' ' in interpreter or not os.path.basename(interpreter).startswith(b'python'):
            unfixed.append(path)
            continue
        interpreter = interpreter.replace(old, new)
        first = b"#!/bin/sh\n'''exec' \"" + interpreter + b'" "$0" "$@"\n' + b"' '''"
    path.write_bytes(first + newline + rest.replace(old, new))
    files += 1
cache = plugin / 'state/nvim/lazy/pkg-cache.lua'
if cache.is_file() and not cache.is_symlink():
    data = cache.read_bytes()
    if old in data:
        cache.write_bytes(data.replace(old, new))
print(f'Updated {links} Neovim links and {files} generated tool launchers.')
for path in unfixed:
    print(f'Reinstall this Mason tool from :Mason; its interpreter cannot move: {path}')
PYTHON
# Ghostty reads its native folder last, so when both exist that one already
# wins, and the XDG one is left for the person to merge.
if [ -e "$GHOSTTY_XDG" ] && [ -e "$GHOSTTY_NATIVE" ]; then
  echo "Left $GHOSTTY_XDG in place because $GHOSTTY_NATIVE also exists. Merge them by hand."
else
  move_folder "$GHOSTTY_XDG" "$GHOSTTY_NATIVE"
fi
echo 'Run setup with the rebuilt Macarchy app, then start a new terminal session.'
echo 'Keep ~/.config/macarchy until setup has replaced the installed service definitions.'
