# Macarchy

A modular macOS desktop setup built around yabai, SketchyBar, Ghostty and a shared theme switcher.

Macarchy used to be easiest to install as one large dotfiles bundle. That made it hard to tell what would change, and harder still to use just one part. The installer now works component by component, backs up files before replacing them and leaves services, themes and macOS security settings alone until you choose to enable them.

## Start here

You need macOS, Git and [Homebrew](https://brew.sh). Clone the repository, open it in a terminal, then see what is available:

```sh
cd macarchy
./install --list
```

Preview an install without changing anything:

```sh
./install --dry-run terminal shell
```

Then install only the parts you want:

```sh
./install terminal shell
./install window-manager sketchybar
./install themes raycast
```

`./install all` is available, but it is not the recommended starting point. The window manager and bar both need a little macOS setup after their files are installed.

## Components

| Component | What it installs |
| --- | --- |
| `window-manager` | yabai, skhd and JankyBorders configs |
| `sketchybar` | The bar, app labels, network speed and optional Apple Silicon metrics |
| `terminal` | A small Ghostty config with a separate generated theme file |
| `shell` | A portable Zsh setup and prompt |
| `nvim` | LazyVim, theme integration and a small set of colour schemes |
| `utilities` | Minimal btop and fastfetch configs |
| `themes` | Theme packs, `theme-switch` and the wallpaper helper |
| `raycast` | Source and tooling for the Raycast theme picker |

The installer prints the next step for each selected component. It never disables SIP, writes a sudoers file, starts a background service or applies a theme on its own.

The `shell` component changes `ZDOTDIR` and backs up `~/.zshenv`. Existing `~/.zprofile` and `~/.zshrc` files stay on disk but are no longer loaded automatically. Review the [shell notes](./docs/install.md#what-happens-to-existing-files) before installing it.

## After installation

Check what Macarchy manages:

```sh
./install status
```

Apply a theme explicitly:

```sh
"$HOME/.local/bin/theme-switch" --list
"$HOME/.local/bin/theme-switch" carbonfox
```

That is the default install path. The `shell` component adds `~/.local/bin` to `PATH`; a themes-only install does not, so the full path works in either case.

Update by pulling the repository and rerunning the components you use. Existing files are backed up under `${XDG_STATE_HOME:-~/.local/state}/macarchy/backups`.

To remove a component and restore the files that were present before Macarchy:

```sh
./install uninstall terminal shell
```

Modified files are kept rather than deleted. Homebrew packages and empty directories are also left in place.

## Repository shape

The configs, installer and Raycast picker stay together because they share one small theme contract. Selective installation now provides the useful separation without making people clone several repositories.

Wallpaper-heavy theme packs should be separate repositories. The old wallpapers have been removed from the current tree, but their blobs remain in Git history. Publishing a completely clean core would therefore mean creating a new snapshot repository or explicitly approving a history rewrite. The existing history has not been rewritten.

## Guides

- [Installation, updates and backups](./docs/install.md)
- [Window management and shortcuts](./docs/window-management.md)
- [SketchyBar and system metrics](./docs/sketchybar.md)
- [Themes and custom theme packs](./docs/themes.md)
- [Raycast theme picker](./raycast-theme/README.md)
- [Troubleshooting](./docs/troubleshooting.md)

Macarchy's original code is MIT licensed. The LazyVim starter files, adapted palettes and app icon map retain their upstream licences; read [THIRD_PARTY_NOTICES.md](./THIRD_PARTY_NOTICES.md) before redistributing them.

Contributions are welcome. Please read [CONTRIBUTING.md](./CONTRIBUTING.md) and run `./scripts/check.sh` before opening a pull request.
