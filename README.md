# Macarchy

A themed, tiling desktop for macOS in one app.

Macarchy sets up and manages [yabai](https://github.com/asmvik/yabai) (tiling),
[skhd](https://github.com/asmvik/skhd) (shortcuts),
[SketchyBar](https://github.com/FelixKratz/SketchyBar) (menu bar) and
[JankyBorders](https://github.com/FelixKratz/JankyBorders) (window borders), and
switches themes across them, Ghostty and your wallpaper at once. You change
things in a native settings window instead of editing dotfiles.

> **Status: early preview.** It works on the author's Macs and is being opened up
> for others. Expect rough edges, and please [report problems](#reporting-problems).

## Requirements

- macOS 26 or later on Apple Silicon
- [Homebrew](https://brew.sh)
- System Integrity Protection can stay **on**. See [SIP](#do-i-need-to-disable-sip).

## Install

1. Install the tools Macarchy configures:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/HarryRandall/macarchy/main/Brewfile | brew bundle --file=-
   ```

   Or one at a time: `brew install asmvik/formulae/yabai asmvik/formulae/skhd
   FelixKratz/formulae/sketchybar FelixKratz/formulae/borders jq`.

2. Download `Macarchy.zip` from the
   [latest release](https://github.com/HarryRandall/macarchy/releases), unzip it
   and move **Macarchy.app** to Applications.

3. Open it. Preview builds are not notarised yet, so macOS will refuse the first
   time. Open **System Settings → Privacy & Security**, scroll down and choose
   **Open Anyway**. Check the download against the SHA-256 on the release page
   first if you like.

4. Follow the setup screen. It shows every file it will change before it changes
   anything, and backs up each one.

5. When macOS asks, allow **yabai** and **skhd** in
   **Privacy & Security → Accessibility**, then restart them from **Advanced**.

### If you already have dotfiles

Setup asks what to do with existing yabai, skhd and SketchyBar configs:

- **Keep mine and add Macarchy.** Your shortcuts and bar stay as they are. Plain
  top-level `yabai -m config` lines move into Macarchy's Layout page; every other
  line, including anything inside loops and conditionals, is kept word for word.
  If you keep your own bar, Macarchy triggers a `macarchy_theme_changed`
  SketchyBar event on theme changes and writes the colours to
  `~/.config/macarchy/generated/bar-colours.sh` for your items to use.
- **Start fresh.** Macarchy's defaults replace them.

Either way the originals are copied to `~/.config/macarchy/backups` first.
**Advanced → Restore original files** puts them all back.

### If you use Ghostty

Your Ghostty config is never rewritten. Setup adds one line:

```
config-file = ?/Users/you/.config/macarchy/generated/ghostty.conf
```

It goes at the end of the last config file Ghostty loads, so theme colours win
and everything else is yours. No Ghostty? That step is skipped.

## What it changes

Everything Macarchy owns lives in **`~/.config/macarchy`**: settings, themes,
backups and files rendered from the active theme. Outside it, it only writes the
startup files each tool reads from a fixed place:

| File | Contents |
|---|---|
| `~/.config/yabai/yabairc` | Hands over to Macarchy, plus a region for your own commands |
| `~/.config/sketchybar/sketchybarrc` | Same |
| `~/.config/borders/bordersrc` | Same |
| `~/.config/skhd/skhdrc` | Your shortcuts (or `~/.skhdrc` if that is what you use). Seeded with defaults on a fresh setup |
| `~/.config/ghostty/config` | One `config-file` line, if you use Ghostty |

Edits outside a file's `macarchy:keep` region are snapshotted and reported, not
silently lost.

## Default shortcuts

Most use **Control + Option** (⌃⌥) so they stay clear of macOS shortcuts. Change
any of them on the Shortcuts page.

| Shortcut | Action |
|---|---|
| ⌃⌥ Return | Open a terminal |
| ⌃⌥ Arrows | Focus window |
| ⌃⌥⇧ Arrows | Swap window |
| ⌃⌥ 1–9 | Switch desktop |
| ⌃⌥⇧ 1–9 | Move window to desktop and follow |
| ⌃⌥ T | Float or tile the window, remembered per app |
| ⌃⌥ F | Fill the screen |
| ⌃⌥ S / R | Flip split / rotate and rebalance |
| ⌃⌥ = / - | Grow / shrink |
| ⌃⌥ . / , | Next / previous theme |
| ⌃⌥ B | Show or hide the menu bar |

## Do I need to disable SIP?

No. Everything Macarchy does works with System Integrity Protection on, using
yabai 7.1.25 or newer: tiling, rules, focusing and swapping windows, switching
desktops and moving windows between them.

yabai's optional *scripting addition* adds extras Macarchy does not rely on,
such as swapping whole desktops, window opacity and sticky windows. It requires
partly disabling SIP; follow
[yabai's guide](https://github.com/asmvik/yabai/wiki/Disabling-System-Integrity-Protection)
only if you want those. Setup health shows its status either way.

## Command line

The app includes a `macarchy` command, used by the startup files:

```sh
~/.config/macarchy/Macarchy.app/Contents/MacOS/macarchy doctor
```

`setup`, `uninstall`, `doctor`, `apply`, `theme <name|next|prev>`,
`wallpaper <theme> <path>`, `rules [toggle]`, `bar toggle` and `restore`.
Run it with no arguments for details.

## Themes

Eight themes ship with the app. A theme is a folder with a `theme.json` and a
Ghostty palette, optionally with wallpapers; Themes → Import adds your own.
Bundled themes do not include wallpapers; add your own images to a theme's
folder and pick them on the Themes page.

### Neovim

Macarchy writes the theme's colourscheme name to
`~/.config/macarchy/generated/nvim-colorscheme` and signals running Neovim
instances. To follow it, add this to your config:

```lua
local function macarchy_colourscheme()
  local file = io.open(vim.fn.expand("~/.config/macarchy/generated/nvim-colorscheme"))
  if not file then return end
  local name = file:read("*l")
  file:close()
  if name and name:match("^[%w_.-]+$") then pcall(vim.cmd.colorscheme, name) end
end
macarchy_colourscheme()
vim.api.nvim_create_autocmd("VimResized", { callback = macarchy_colourscheme })
```

### Custom builds

A file in `~/.config/macarchy/bin` replaces the Homebrew copy of the same tool,
for example a patched `borders`.

## Uninstall

1. **Advanced → Restore original files** (or `macarchy uninstall`) puts back
   every file setup replaced and removes the ones it created.
2. Delete Macarchy.app, and `~/.config/macarchy` if you do not want your
   settings and themes.

## Reporting problems

**Report a problem** in the app prepares an issue with your Mac model, versions
and check results. Your name, username, computer name and home folder are
removed, and you see the whole report before anything is sent. Or
[open an issue](https://github.com/HarryRandall/macarchy/issues) directly.

## Building from source

Requires Xcode 27.

```sh
swift build && swift test && ./tools/lint.sh
./tools/build.sh release        # .build/artifacts/Macarchy.app, not installed
./tools/install.sh              # copy to /Applications and run setup
```

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request, and
[docs/architecture.md](docs/architecture.md) for how the pieces fit.

## Licence

Macarchy is free software under the [GNU General Public License v3.0](LICENSE).
Bundled third-party work is listed in [CREDITS.md](CREDITS.md).
