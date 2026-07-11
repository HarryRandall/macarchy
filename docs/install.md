# Install and update Macarchy

Macarchy copies files rather than symlinking them. That makes an installed setup independent of the clone, while a manifest records which files belong to each component.

## Requirements

- A currently supported macOS release
- [Homebrew](https://brew.sh)
- Git
- Zsh and the macOS system Bash, both included with macOS

Raycast development needs Node.js 22.22.2 or newer. Apple Silicon system metrics use `macmon`; Intel Macs still get the bar, network and battery items but show placeholders for CPU, GPU and RAM sensors.

## Choose components

```sh
./install --list
./install --dry-run window-manager sketchybar
./install window-manager sketchybar
```

You can pass several components at once. Running the same command again updates the managed files and leaves unrelated components alone.

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

## Update

```sh
git pull --ff-only
./install terminal shell themes
./install status terminal shell themes
```

Rerun only the components you use. When Homebrew upgrades yabai, an optional scripting-addition sudoers hash must also be refreshed. See the [window management guide](./window-management.md).

## Uninstall

```sh
./install --dry-run uninstall sketchybar
./install uninstall sketchybar
```

Uninstall restores the original files where backups exist. It does not uninstall Homebrew packages, stop services or remove empty directories because those may be shared with another setup.
