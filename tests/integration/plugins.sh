#!/bin/bash
# Exercise plugin storage and migration without opening an editor or real services.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
CLI="${MACARCHY_TEST_CLI:-$REPO/.build/debug/macarchy}"
TEST_ROOT="$(mktemp -d -t macarchy-plugins-test)"
trap 'rm -rf "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/resources"
cp -R "$REPO/resources/themes" "$REPO/resources/plugins" "$REPO/resources/launchers" "$REPO/resources/integrations/skhd" "$TEST_ROOT/resources/"
export MACARCHY_HOME="$TEST_ROOT/home" MACARCHY_RESOURCES="$TEST_ROOT/resources"
export MACARCHY_SEARCH_PATH= MACARCHY_APPLICATIONS="$TEST_ROOT/applications"
mkdir -p "$MACARCHY_HOME"
"$CLI" setup --no-apply > "$TEST_ROOT/setup.log"
PLUGIN="$MACARCHY_HOME/Library/Application Support/Macarchy/plugins/neovim"
# Setup leaves Neovim and the shell alone; they are plugins of their own.
[ ! -e "$PLUGIN" ]
[ ! -e "$MACARCHY_HOME/.zshenv" ]
[ ! -e "$MACARCHY_HOME/.zshrc" ]
[ ! -e "$MACARCHY_HOME/.config" ]
# What an earlier setup seeded: the editable configuration and the PATH line.
mkdir -p "$PLUGIN"
cp -R "$REPO/resources/plugins/neovim/config" "$PLUGIN/config"
printf '\n-- preserved local edit\n' >> "$PLUGIN/config/nvim/init.lua"
PATH_LINE='export PATH="$HOME/Library/Application Support/Macarchy/Macarchy.app/Contents/MacOS:$PATH"'
printf '%s\n' "$PATH_LINE" > "$MACARCHY_HOME/.zshenv"
printf '%s\n' "$PATH_LINE" > "$MACARCHY_HOME/.zshrc"
"$CLI" setup --no-apply > "$TEST_ROOT/setup-again.log"
grep -q 'preserved local edit' "$PLUGIN/config/nvim/init.lua"
[ "$(grep -c '^export PATH=' "$MACARCHY_HOME/.zshenv")" = 1 ]
[ "$(grep -c '^export PATH=' "$MACARCHY_HOME/.zshrc")" = 1 ]
# An edit made after setup must survive uninstall.
printf "alias ll='ls -l'\n" >> "$MACARCHY_HOME/.zshrc"
cat > "$TEST_ROOT/fake-nvim" <<'FAKE'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$NVIM_APPNAME" "$@"
FAKE
chmod +x "$TEST_ROOT/fake-nvim"
MACARCHY_NVIM_BINARY="$TEST_ROOT/fake-nvim" "$REPO/resources/plugins/neovim/nvim" 'file with spaces.md' > "$TEST_ROOT/actual"
printf '%s\n' "$PLUGIN/config" "$PLUGIN/data" "$PLUGIN/state" "$PLUGIN/cache" nvim \
  --cmd 'lua dofile(vim.env.MACARCHY_NVIM_ENVIRONMENT)' 'file with spaces.md' > "$TEST_ROOT/expected"
cmp "$TEST_ROOT/actual" "$TEST_ROOT/expected"
for tool in yabai sketchybar; do
  config="$MACARCHY_HOME/Library/Application Support/Macarchy/config/${tool}rc"
  printf '#!/bin/bash\nprintf ran\n' > "$config"
  chmod +x "$config"
  [ "$(/bin/sh -c "$REPO/resources/launchers/macarchy-${tool}rc")" = ran ]
done
mkdir -p "$MACARCHY_HOME/.config/nvim" "$MACARCHY_HOME/.local/share/nvim/lazy/example" "$MACARCHY_HOME/.config/ghostty"
printf 'return {}\n' > "$MACARCHY_HOME/.config/nvim/init.lua"
ln -s "$MACARCHY_HOME/.local/share/nvim/lazy/example" "$MACARCHY_HOME/.local/share/nvim/query-link"
mkdir -p "$MACARCHY_HOME/.local/share/nvim/mason/bin"
printf '#!/bin/sh\nexec "%s/.local/share/nvim/lazy/example/tool" "$@"\n' "$MACARCHY_HOME" > "$MACARCHY_HOME/.local/share/nvim/mason/bin/example"
chmod +x "$MACARCHY_HOME/.local/share/nvim/mason/bin/example"
VENV="$MACARCHY_HOME/.local/share/nvim/mason/packages/example/venv/bin"
mkdir -p "$VENV"
printf '#!/bin/sh\nexec /usr/bin/python3 "$@"\n' > "$VENV/python"
chmod +x "$VENV/python"
printf '#!%s/python\nprint("python tool ran")\n' "$VENV" > "$VENV/example-py"
chmod +x "$VENV/example-py"
printf 'font-size = 13\n' > "$MACARCHY_HOME/.config/ghostty/config"
"$REPO/tools/migrate-plugins.sh" > "$TEST_ROOT/migrate.log"
[ ! -e "$MACARCHY_HOME/.config/nvim" ]
[ ! -e "$MACARCHY_HOME/.config/ghostty" ]
[ ! -e "$MACARCHY_HOME/.local/share/nvim" ]
[ -d "$PLUGIN/data/nvim/lazy/example" ]
[ "$(readlink "$PLUGIN/data/nvim/query-link")" = "$PLUGIN/data/nvim/lazy/example" ]
grep -qF "$PLUGIN/data/nvim/lazy/example/tool" "$PLUGIN/data/nvim/mason/bin/example"
[ "$("$PLUGIN/data/nvim/mason/packages/example/venv/bin/example-py")" = 'python tool ran' ]
[ "$(cat "$PLUGIN/config/nvim/init.lua")" = 'return {}' ]
grep -q 'font-size = 13' "$MACARCHY_HOME/Library/Application Support/com.mitchellh.ghostty/config"
BACKUP_INIT="$(find "$MACARCHY_HOME/Library/Application Support/Macarchy/backups" -name init.lua -print -quit)"
[ -n "$BACKUP_INIT" ]
grep -q 'preserved local edit' "$BACKUP_INIT"
"$CLI" uninstall > "$TEST_ROOT/uninstall.log"
[ ! -e "$MACARCHY_HOME/.zshenv" ]
grep -qx "alias ll='ls -l'" "$MACARCHY_HOME/.zshrc"
[ "$(grep -c '^export PATH=' "$MACARCHY_HOME/.zshrc")" = 0 ]
echo 'Plugin launcher, migration, preservation and shell restoration checks passed.'
