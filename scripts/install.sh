#!/bin/bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
[ -x dist/macarchy ] || { echo 'Build first: ./scripts/build_app.sh release' >&2; exit 1; }
if pgrep -x MacarchySettings >/dev/null; then
  echo 'Close the running Macarchy app before installing.' >&2
  exit 1
fi
BACKUP_DIR="$HOME/.local/state/macarchy-migration/$(date +%Y%m%dT%H%M%S)-$$"
CONFIG_FILES=(borders/bordersrc yabai/yabairc yabai/sync_float_rules.sh yabai/apply_float_state.sh yabai/toggle_float_persist.sh sketchybar/sketchybarrc macarchy-settings/settings.json macarchy-settings/generated.json)
mkdir -p "$BACKUP_DIR" "$HOME/.local/bin"
for entry in macarchy theme-switch; do
  [ ! -f "$HOME/.local/bin/$entry" ] || cp -p "$HOME/.local/bin/$entry" "$BACKUP_DIR/$entry"
done
for entry in "${CONFIG_FILES[@]}"; do
  if [ -f "$HOME/.config/$entry" ]; then
    mkdir -p "$BACKUP_DIR/config/$(dirname "$entry")"
    cp -p "$HOME/.config/$entry" "$BACKUP_DIR/config/$entry"
  fi
done
rollback() {
  install_status=$?
  trap - ERR
  set +e
  for entry in macarchy theme-switch; do
    if [ -f "$BACKUP_DIR/$entry" ]; then
      cp -p "$BACKUP_DIR/$entry" "$HOME/.local/bin/$entry"
    else
      rm -f "$HOME/.local/bin/$entry"
    fi
  done
  for entry in "${CONFIG_FILES[@]}"; do
    if [ -f "$BACKUP_DIR/config/$entry" ]; then
      cp -p "$BACKUP_DIR/config/$entry" "$HOME/.config/$entry"
    else
      rm -f "$HOME/.config/$entry"
    fi
  done
  echo "Installation failed; previous files restored from $BACKUP_DIR" >&2
  exit "$install_status"
}
trap rollback ERR
echo "Rollback files: $BACKUP_DIR"
cp dist/macarchy "$HOME/.local/bin/macarchy.new"
mv "$HOME/.local/bin/macarchy.new" "$HOME/.local/bin/macarchy"
"$HOME/.local/bin/macarchy" migrate
cp dotfiles/theme-switch "$HOME/.local/bin/theme-switch"
for entry in sync_float_rules.sh apply_float_state.sh toggle_float_persist.sh; do
  cp "dotfiles/$entry" "$HOME/.config/yabai/$entry"
done
"$HOME/.local/bin/macarchy" doctor
trap - ERR
