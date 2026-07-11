# Install and update Macarchy

Macarchy copies files rather than symlinking them. That makes an installed setup independent of the clone, while a manifest records which files belong to each component.

## Requirements

- A currently supported macOS release
- [Homebrew](https://brew.sh)
- Git
- Zsh and the macOS system Bash, both included with macOS

Raycast development needs Node.js 22.22.2 or newer. Apple Silicon system metrics use `macmon`; Intel Macs still get the bar, network and battery items, while the CPU, GPU and RAM tiles are omitted.

## Choose components

```sh
./install --list
./install --dry-run window-manager sketchybar
./install window-manager sketchybar
```

You can pass several components at once. Running the same command again updates the managed files and leaves unrelated components alone.

Commands are installed in `~/.local/bin` by default. Set `MACARCHY_BIN_HOME` before running the installer if you need another location, and keep using the same value for later updates and uninstall commands.

The installer also installs a component's Homebrew dependencies. Third-party taps are used for yabai, skhd, JankyBorders and SketchyBar. If your Homebrew setup requires explicit tap trust, review the tap and trust only the formulae you plan to install, for example:

```sh
brew trust --formula asmvik/formulae/yabai asmvik/formulae/skhd
brew trust --formula FelixKratz/formulae/borders FelixKratz/formulae/sketchybar
```

Then rerun the installer.

## What happens to existing files

Before replacing a file, Macarchy copies it to:

```text
${XDG_STATE_HOME:-~/.local/state}/macarchy/backups/<date-and-process>/<component>/
```

Manifests live beside the backups under `macarchy/manifests`. They store the installed checksum and the path to the original backup. This is what makes status checks and safe uninstall possible.

If you edit a managed file and run uninstall, Macarchy keeps your edited version and reports it. It will not silently delete work it no longer recognises.

The `shell` component replaces `~/.zshenv` with a small bootstrap that sets `ZDOTDIR` to `${XDG_CONFIG_HOME:-~/.config}/zsh`. Once that is active, Zsh loads Macarchy's `.zprofile` and `.zshrc` from the new directory instead of existing copies in your home directory. Those home-directory files are not deleted, but they become inactive. Review them first and move settings you still need into the installed config or `${XDG_CONFIG_HOME:-~/.config}/zsh/local.zsh`.

## Start only what you use

The installer does not start background services. After reviewing the installed configs, use the relevant commands:

```sh
yabai --start-service
skhd --start-service
brew services start borders
brew services start sketchybar
```

yabai and skhd need Accessibility access in System Settings under Privacy & Security. SketchyBar also expects "Displays have separate Spaces" to be enabled in Desktop & Dock.

## Custom XDG paths

Files honour `XDG_CONFIG_HOME`, `XDG_DATA_HOME` and `XDG_STATE_HOME`. If `XDG_CONFIG_HOME` is not `~/.config`, launchd services and GUI applications also need to see it:

```sh
launchctl setenv XDG_CONFIG_HOME "$XDG_CONFIG_HOME"
```

Run that before starting yabai, skhd, SketchyBar or Ghostty. The installer prints a reminder when it detects a custom path.

## Raycast source and runtime

The `raycast` component installs development source in:

```text
${XDG_DATA_HOME:-~/.local/share}/macarchy/raycast-theme
```

Install its dependencies and register the command from that directory. Raycast generates the active command under `~/.config/raycast/extensions/theme-switcher` itself. Never run `npm install` in that generated directory. Keeping `node_modules` there gives the command a second React instance and causes an invalid hook error.

The installer moves any legacy runtime `node_modules` into Macarchy's normal backup directory. It leaves Raycast's generated command in place when you update or uninstall the source component.

## Update

```sh
git pull --ff-only
./install terminal shell themes
./install status terminal shell themes
```

Rerun only the components you use. When Homebrew upgrades yabai, an optional scripting-addition sudoers hash must also be refreshed. See the [window management guide](./window-management.md).

If a managed file has local edits, an ordinary update stops before replacing it. Review the file first, then rerun that component with `--force` if you want the repository version. The installer keeps an additional backup of the edited copy.

```sh
./install --force terminal
```

When upgrading from the old all-in-one setup, the installer also handles two legacy cases:

- An existing Ghostty `config` file is backed up and replaced with a comment-only compatibility file, preventing it from overriding the newer `config.ghostty`.
- On the first `window-manager` install, an existing unmanaged `skhdrc` is copied to `local.skhdrc` before the public configuration is installed. An existing `local.skhdrc` is never overwritten.
- Older Raycast source is no longer managed inside Raycast's generated extension directory, and unsafe runtime dependencies are moved into a backup.

The `themes` component leaves existing theme directories and wallpaper files in place. If Macarchy ships a file at the same path, that individual file still goes through the normal backup and replacement process.

## Uninstall

```sh
./install --dry-run uninstall sketchybar
./install uninstall sketchybar
```

Uninstall restores the original files where backups exist. Removing the `themes` component also removes unchanged files generated by `theme-switch`, while preserving any that were edited afterwards. It does not uninstall Homebrew packages, stop services or remove empty directories because those may be shared with another setup.
