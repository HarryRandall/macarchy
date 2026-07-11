# Themes

The themes component keeps colours in sync across the parts of Macarchy you have installed. The built-in themes are palette-only; wallpaper-heavy packs can be installed separately.

```sh
./install themes
"$HOME/.local/bin/theme-switch" --list
"$HOME/.local/bin/theme-switch" carbonfox
"$HOME/.local/bin/theme-switch" next
"$HOME/.local/bin/theme-switch" prev
```

The installer uses `~/.local/bin/theme-switch` unless `MACARCHY_BIN_HOME` is set. Use the full path when the `shell` component is not installed, because a themes-only install does not change `PATH`.

An external pack can include wallpapers. Choose one with a path relative to its theme directory:

```sh
"$HOME/.local/bin/theme-switch" --background my-theme backgrounds/my-wallpaper.jpg
```

The selected background is remembered per theme. Built-in palettes leave the desktop picture unchanged.

Theme choices are stored under `${XDG_STATE_HOME:-~/.local/state}/macarchy/themes`, separately from the theme pack itself. This keeps external theme repositories clean and allows the pack directory to be read-only.

## What gets updated

`theme-switch` can update:

- macOS light or dark appearance and the desktop picture
- Raycast's current, dark and light appearance defaults
- Ghostty's dedicated `macarchy-theme.ghostty` colour file
- Neovim's selected colour-scheme state
- a generated btop theme
- JankyBorders colours
- SketchyBar colours
- the Zsh prompt colour state

Missing applications are skipped. The script writes only Macarchy-owned generated files.

## Theme format

Each theme is a directory containing `theme.env` and `ghostty.conf`. Images are optional and can sit in the theme directory or a `backgrounds` subdirectory. `theme.env` is parsed as data and is never sourced as shell code.

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
| `SKETCHYBAR_TEXT_COLOR` | Optional bar text colour. Defaults to Ghostty's foreground colour |
| `FIREFOX_ACCENT` | Optional legacy accent hint used for palette-based shell colours |

Ghostty files accept palette and colour keys plus these visual settings used by the original packs:

- `background-opacity`, from `0` to `1`
- `window-padding-x` and `window-padding-y`, as one or two non-negative numbers
- `window-padding-balance`, as `true` or `false`

A downloaded theme still cannot use its Ghostty file to change commands, fonts or key bindings.

Run `./tests/theme_validation_test.sh` before sharing a pack.

## External theme packs

The theme directory is intentionally independent from the rest of the configs. You can point the command at another pack collection:

```sh
MACARCHY_THEMES_DIR="$HOME/.local/share/my-themes" "$HOME/.local/bin/theme-switch" --list
```

The Raycast extension has a matching Themes Directory preference. A theme repo can therefore be installed or linked separately without changing the core scripts.

Locally retained copies of the original `awakening`, `blackgold`, `carbonfox`, `city-783`, `lumon`, `matte-black`, `midnight` and `turbonite` packs remain compatible. Their names are preserved in `--list`, `next` and `prev`. Saved `lumon` or `turbonite` state is mapped to the built-in `cool-blue` or `amber-metal` palette only when the original local directory is absent.

The old bundled wallpapers were removed after the provenance audit found unclear and restricted redistribution terms. New wallpaper-heavy packs should live in separate repositories so the core clone stays small and each pack can carry its own licence and credits.
