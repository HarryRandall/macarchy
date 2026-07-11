# Themes

The themes component keeps colours in sync across the parts of Macarchy you have installed. The built-in themes are palette-only; wallpaper-heavy packs can be installed separately.

```sh
./install themes
theme-switch --list
theme-switch carbonfox
theme-switch next
theme-switch prev
```

An external pack can include wallpapers. Choose one with a path relative to its theme directory:

```sh
theme-switch --background my-theme backgrounds/my-wallpaper.jpg
```

The selected background is remembered per theme. Built-in palettes leave the desktop picture unchanged.

## What gets updated

`theme-switch` can update:

- macOS light or dark appearance and the desktop picture
- Ghostty's dedicated `macarchy-theme.ghostty` colour file
- Neovim's selected colour-scheme state
- a generated btop theme
- JankyBorders colours
- SketchyBar colours
- the Zsh prompt colour state

Missing applications are skipped. The script only writes Macarchy-owned generated files, except for btop's `color_theme` setting.

## Theme format

Each theme is a directory containing `theme.env`, `ghostty.conf` and one or more images. `theme.env` is parsed as data and is never sourced as shell code.

Supported keys are:

| Key | Purpose |
| --- | --- |
| `DARK_MODE` | `true` or `false` |
| `WALLPAPER` | Relative image path inside the theme |
| `NVIM_COLORSCHEME` | Installed Neovim colour-scheme name |
| `BORDER_ACTIVE` | Active border in `0xAARRGGBB` format |
| `BORDER_INACTIVE` | Inactive border in `0xAARRGGBB` format |
| `BORDER_WIDTH` | JankyBorders width |
| `SKETCHYBAR_BAR_COLOR` | Optional bar colour |
| `SKETCHYBAR_TEXT_COLOR` | Optional bar text colour |

Ghostty files are restricted to palette and colour keys. A downloaded theme cannot use them to change commands, fonts or key bindings.

Run `./tests/theme_validation_test.sh` before sharing a pack.

## External theme packs

The theme directory is intentionally independent from the rest of the configs. You can point the command at another pack collection:

```sh
MACARCHY_THEMES_DIR="$HOME/.local/share/my-themes" theme-switch --list
```

The Raycast extension has a matching Themes Directory preference. A theme repo can therefore be installed or linked separately without changing the core scripts.

The old bundled wallpapers were removed after the provenance audit found unclear and restricted redistribution terms. New wallpaper-heavy packs should live in separate repositories so the core clone stays small and each pack can carry its own licence and credits.
