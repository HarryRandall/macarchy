# Macarchy

My personal macOS desktop setup, built around yabai, skhd, SketchyBar, Ghostty, Raycast, Neovim, zsh, btop, borders, and a few theme scripts.

Mostly config files, small scripts, and app settings for the way I like my Mac set up.

## Preview

![Macarchy preview](./media/macarchy-preview.gif)

![Awakening](./media/macarchy-awakening.png)
![Lumon](./media/macarchy-lumon.png)

## Components

- `bin/`: Theme and wallpaper scripts.
- `themes/`: Theme files, wallpapers, and Ghostty palettes.
- `raycast-theme/`: Raycast theme switcher extension.
- `yabai/`: Window manager config and helper scripts.
- `skhd/`: Keyboard shortcuts.
- `sketchybar/`: Menu bar config, items, and plugins.
- `ghostty/`, `nvim/`, `zsh/`, `btop/`, `fastfetch/`, `neofetch/`, `borders/`: App configs.
- `launchagents/`: Launch agents for background services.

## Install

One-line install:

```bash
brew install btop borders desktoppr fastfetch fish jq neofetch neovim ripgrep sketchybar skhd yabai && brew install --cask ghostty raycast && mkdir -p "$HOME/.local/bin" "$HOME/.config" "$HOME/.config/skhd" "$HOME/.config/zsh" "$HOME/Library/LaunchAgents" && rsync -a bin/ "$HOME/.local/bin/" && rsync -a borders/ "$HOME/.config/borders/" && rsync -a btop/ "$HOME/.config/btop/" && rsync -a fastfetch/ "$HOME/.config/fastfetch/" && rsync -a ghostty/ "$HOME/.config/ghostty/" && rsync -a neofetch/ "$HOME/.config/neofetch/" && rsync -a nvim/ "$HOME/.config/nvim/" && rsync -a sketchybar/ "$HOME/.config/sketchybar/" && rsync -a themes/ "$HOME/.config/themes/" && rsync -a zsh/ "$HOME/.config/zsh/" && printf 'export ZDOTDIR="$HOME/.config/zsh"\n[[ -r "$ZDOTDIR/.zshenv" ]] && source "$ZDOTDIR/.zshenv"\n' > "$HOME/.zshenv" && rsync -a yabai/ "$HOME/.config/yabai/" && rsync -a skhd/skhdrc "$HOME/.config/skhd/skhdrc" && rsync -a launchagents/ "$HOME/Library/LaunchAgents/" && for service in com.asmvik.yabai com.koekeishiya.skhd homebrew.mxcl.sketchybar; do launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/$service.plist" 2>/dev/null || launchctl kickstart -k "gui/$(id -u)/$service"; done && "$HOME/.local/bin/theme-switch" "$(cat "$HOME/.config/themes/.current")"
```

Step by step:

<details>
<summary>Tools</summary>

```bash
brew install btop borders desktoppr fastfetch fish jq neofetch neovim ripgrep sketchybar skhd yabai
brew install --cask ghostty raycast
```

</details>

<details>
<summary>Themes and scripts</summary>

```bash
mkdir -p "$HOME/.local/bin" "$HOME/.config/themes" "$HOME/.config/zsh"
rsync -a bin/ "$HOME/.local/bin/"
rsync -a themes/ "$HOME/.config/themes/"
rsync -a zsh/ "$HOME/.config/zsh/"
printf 'export ZDOTDIR="$HOME/.config/zsh"\n[[ -r "$ZDOTDIR/.zshenv" ]] && source "$ZDOTDIR/.zshenv"\n' > "$HOME/.zshenv"
```

</details>

<details>
<summary>Window management</summary>

```bash
mkdir -p "$HOME/.config" "$HOME/.config/skhd"
rsync -a borders/ "$HOME/.config/borders/"
rsync -a yabai/ "$HOME/.config/yabai/"
rsync -a skhd/skhdrc "$HOME/.config/skhd/skhdrc"
```

</details>

<details>
<summary>SketchyBar</summary>

```bash
mkdir -p "$HOME/.config"
rsync -a sketchybar/ "$HOME/.config/sketchybar/"
```

</details>

<details>
<summary>App configs</summary>

```bash
mkdir -p "$HOME/.config"
rsync -a btop/ "$HOME/.config/btop/"
rsync -a fastfetch/ "$HOME/.config/fastfetch/"
rsync -a ghostty/ "$HOME/.config/ghostty/"
rsync -a neofetch/ "$HOME/.config/neofetch/"
rsync -a nvim/ "$HOME/.config/nvim/"
```

</details>

<details>
<summary>Launch agents</summary>

```bash
mkdir -p "$HOME/Library/LaunchAgents"
rsync -a launchagents/ "$HOME/Library/LaunchAgents/"

for service in com.asmvik.yabai com.koekeishiya.skhd homebrew.mxcl.sketchybar; do
  launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/$service.plist" 2>/dev/null || launchctl kickstart -k "gui/$(id -u)/$service"
done
```

</details>

<details>
<summary>Apply the current theme</summary>

```bash
"$HOME/.local/bin/theme-switch" "$(cat "$HOME/.config/themes/.current")"
```

</details>

<details>
<summary>Just sync configs</summary>

```bash
mkdir -p "$HOME/.local/bin" "$HOME/.config" "$HOME/.config/skhd" "$HOME/.config/zsh" && rsync -a bin/ "$HOME/.local/bin/" && rsync -a borders/ "$HOME/.config/borders/" && rsync -a btop/ "$HOME/.config/btop/" && rsync -a fastfetch/ "$HOME/.config/fastfetch/" && rsync -a ghostty/ "$HOME/.config/ghostty/" && rsync -a neofetch/ "$HOME/.config/neofetch/" && rsync -a nvim/ "$HOME/.config/nvim/" && rsync -a sketchybar/ "$HOME/.config/sketchybar/" && rsync -a themes/ "$HOME/.config/themes/" && rsync -a zsh/ "$HOME/.config/zsh/" && printf 'export ZDOTDIR="$HOME/.config/zsh"\n[[ -r "$ZDOTDIR/.zshenv" ]] && source "$ZDOTDIR/.zshenv"\n' > "$HOME/.zshenv" && rsync -a yabai/ "$HOME/.config/yabai/" && rsync -a skhd/skhdrc "$HOME/.config/skhd/skhdrc"
```

</details>

## Raycast

One-line setup:

```bash
mkdir -p "$HOME/.config/raycast/extensions" && rsync -a raycast-theme/ "$HOME/.config/raycast/extensions/theme-switcher/" && cd "$HOME/.config/raycast/extensions/theme-switcher" && ray develop
```

Step by step:

<details>
<summary>Install the extension</summary>

```bash
mkdir -p "$HOME/.config/raycast/extensions"
rsync -a raycast-theme/ "$HOME/.config/raycast/extensions/theme-switcher/"

cd "$HOME/.config/raycast/extensions/theme-switcher"
ray develop
```

</details>

The extension reads themes from `~/.config/themes`, previews the active wallpaper, and calls `~/.local/bin/theme-switch`. The shell script remains the source of truth.

## Key Bindings

Modifier symbols: `⌘` Command, `⌃` Control, `⇧` Shift. Space numbers use `1` through `9`, with `0` for space 10.

| Shortcut | Action |
| --- | --- |
| `⌃↩` | Open Ghostty. |
| `⌘Q` | Quit the current app. In Chrome, close the current profile window instead. |
| `⌘W` | In Messages, TablePlus, and Obsidian, quit the app instead of closing a window. |
| Media keys | Control Spotify, but only when Spotify is already running. |
| `⌃F` | Toggle fullscreen for the focused window. |
| `⌘⇧B` or `⌃⇧B` | Open the Firefox profile manager. |
| `⌘⇧F` | Open the home folder in Finder. |
| `⌘←/↓/↑/→` or `⌃←/↓/↑/→` | Focus the window in that direction. |
| `⌘⇧←/↓/↑/→` or `⌃⇧←/↓/↑/→` | Swap the focused window in that direction, then focus it. |
| `⌘1..0` or `⌃1..0` | Switch to a space. |
| `⌘⌃1..0` | Swap the current space with another space. |
| `⌘⇧1..0` or `⌃⇧1..0` | Move the focused window to a space and follow it. |
| `⌃T` | Toggle floating or tiled mode for the focused window and remember it for that app. |
| `⌃J` | Toggle the split direction. |
| `⌃L` | Rotate and rebalance the current layout. |
| `⌃=` / `⌃-` | Adjust the focused window split ratio. |
| `⌃⇧S` | Take an interactive screenshot to the clipboard. |
| `⌘⌃=` or `⌘⌃⇧=` | Switch to the next Macarchy theme. |
| `⌘⌃-` | Switch to the previous Macarchy theme. |

<details>
<summary>SIP and yabai</summary>

This setup assumes Apple Silicon with the `yabai` scripting addition and this boot arg:

```bash
sudo nvram boot-args=-arm64e_preview_abi
```

The working SIP profile is partial SIP with filesystem, debug, and NVRAM protections disabled:

```bash
csrutil enable --without fs --without debug --without nvram
```

A full replication sequence for a new Mac:

1. Boot to Recovery.
2. In Startup Security Utility, choose Reduced Security and allow user management of kernel extensions.
3. In Recovery Terminal:

```bash
csrutil disable
```

4. Reboot to macOS.
5. Set the yabai boot arg:

```bash
sudo nvram boot-args=-arm64e_preview_abi
```

6. Reboot to Recovery.
7. Re-enable the intended partial SIP profile:

```bash
csrutil enable --without fs --without debug --without nvram
```

8. Reboot to macOS.

`csrutil status` will show `unknown (Custom Configuration)`. That is expected for this profile.

</details>
