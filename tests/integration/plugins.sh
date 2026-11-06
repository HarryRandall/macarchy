#!/bin/bash
# Exercise Neovim's setup and launchers without opening an editor or real services.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
CLI="${MACARCHY_TEST_CLI:-$REPO/.build/debug/macarchy}"
TEST_ROOT="$(mktemp -d -t macarchy-plugins-test)"
trap 'rm -rf "$TEST_ROOT"' EXIT
"$REPO/tools/stage-resources.sh" "$TEST_ROOT/resources"
export MACARCHY_HOME="$TEST_ROOT/home" MACARCHY_RESOURCES="$TEST_ROOT/resources"
export MACARCHY_SEARCH_PATH= MACARCHY_APPLICATIONS="$TEST_ROOT/applications"
mkdir -p "$MACARCHY_HOME"
"$CLI" setup --no-apply > "$TEST_ROOT/setup.log"
PLUGIN="$MACARCHY_HOME/Library/Application Support/Macarchy/plugins/neovim"
# Without --neovim, setup leaves Neovim and the shell alone.
[ ! -e "$PLUGIN" ]
[ ! -e "$MACARCHY_HOME/.zshenv" ]
[ ! -e "$MACARCHY_HOME/.zshrc" ]
[ ! -e "$MACARCHY_HOME/.config" ]
# With --neovim, setup seeds the editable configuration and adds the PATH
# line to both zsh files.
"$CLI" setup --no-apply --neovim > "$TEST_ROOT/setup-neovim.log"
cmp "$REPO/resources/neovim/config/nvim/init.lua" "$PLUGIN/config/nvim/init.lua"
[ "$(grep -c '^export PATH=' "$MACARCHY_HOME/.zshenv")" = 1 ]
[ "$(grep -c '^export PATH=' "$MACARCHY_HOME/.zshrc")" = 1 ]
[ ! -e "$MACARCHY_HOME/.config" ]
# Setting up again keeps the person's edits and adds no second line.
printf '\n-- preserved local edit\n' >> "$PLUGIN/config/nvim/init.lua"
"$CLI" setup --no-apply --neovim > "$TEST_ROOT/setup-again.log"
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
MACARCHY_NVIM_BINARY="$TEST_ROOT/fake-nvim" "$REPO/resources/neovim/nvim" 'file with spaces.md' > "$TEST_ROOT/actual"
printf '%s\n' "$PLUGIN/config" "$PLUGIN/data" "$PLUGIN/state" "$PLUGIN/cache" nvim \
  --cmd 'lua dofile(vim.env.MACARCHY_NVIM_ENVIRONMENT)' 'file with spaces.md' > "$TEST_ROOT/expected"
cmp "$TEST_ROOT/actual" "$TEST_ROOT/expected"
for tool in yabai sketchybar; do
  config="$MACARCHY_HOME/Library/Application Support/Macarchy/config/${tool}rc"
  printf '#!/bin/bash\nprintf ran\n' > "$config"
  chmod +x "$config"
  [ "$(/bin/sh -c "$REPO/resources/${tool}/macarchy-${tool}rc")" = ran ]
done
"$CLI" uninstall > "$TEST_ROOT/uninstall.log"
[ ! -e "$MACARCHY_HOME/.zshenv" ]
grep -qx "alias ll='ls -l'" "$MACARCHY_HOME/.zshrc"
[ "$(grep -c '^export PATH=' "$MACARCHY_HOME/.zshrc")" = 0 ]
echo 'Plugin launcher, preservation and shell restoration checks passed.'
