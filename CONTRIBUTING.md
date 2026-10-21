# Contributing

Macarchy configures a daily-use desktop. Keep development builds separate from
installation, preserve unrelated work, and commit focused, reviewable changes.
Read [the architecture guide](docs/architecture.md) for the shared app and CLI design.

## Build and install

Requires an Apple Silicon Mac with macOS 26 or later, Xcode 27 and
[Homebrew](https://brew.sh). Open Xcode once to finish installing its components.

```sh
git clone https://github.com/HarryRandall/macarchy.git
cd macarchy
brew bundle
brew install swiftlint
./tools/build.sh release
```

The build creates `.build/artifacts/Macarchy.app` and does not install it.
To install, close Macarchy first and make sure no other session is editing or
testing the active desktop:

```sh
./tools/install.sh
open /Applications/Macarchy.app
```

The installer copies the app to `/Applications`, runs setup and prints a health
check. Setup backs up existing configuration before changing it. To review the
setup plan interactively instead, copy the built app to Applications and open it.

Local builds use ad-hoc signing by default. Rebuilding can reset macOS permissions.
For a stable signature, create a self-signed Code Signing certificate in Keychain
Access and set `MACARCHY_SIGN_IDENTITY` to its name before building.

If macOS blocks the first launch, use **System Settings → Privacy & Security →
Open Anyway**. Allow yabai and skhd in **Privacy & Security → Accessibility**
when prompted, then restart them from **Advanced**.

## Checks

Run `swift build`, `swift test`, `./tools/lint.sh` and
`macarchy/tests/integration/setup.sh`. CI runs the same. Tests must use temporary
homes (`MACARCHY_HOME`), fake tools (`MACARCHY_SEARCH_PATH`) and must never alter
the running desktop. Use Xcode 27's `swift-format`; CI installs SwiftLint through Homebrew.

## Structure and naming

Directories use lowercase names with hyphens between words. Swift filenames
match their primary type. Keep conventional filenames such as `Package.swift`
and `Info.plist`. Do not add empty folders for speculative future features.

The App and CLI targets use the shared Macarchy target. UI state belongs in
`macarchy/app`; themes, configuration and integration behaviour belong in
`macarchy/core`. Add targets or protocols only when a concrete dependency or test
needs them. Prefer small concrete types over generic frameworks.

## Behaviour

- Opening and refreshing the app are read-only. Migration is explicit.
- JSON owns saved preferences; daemon queries report observed state.
- Apply before committing preferences. Report partial application and failed
  persistence clearly. Never silently treat invalid configuration as empty.
- One implementation serves the app, command and startup paths.
- Call executables with argument arrays through the shared process runner.
- Generate required native formats; do not maintain a second editable settings
  source in shell files.
- Snapshot before destructive writes. Preserve custom startup regions and
  report externally edited generated files.
- Everything Macarchy owns lives in `~/.config/macarchy`, through `Paths`.
  Write outside it only where a tool requires a fixed location, and only after
  `Setup` has backed the file up.
- Every integration is optional. Detect it, skip it when it is missing, and say
  so; never fail a whole operation because one tool is absent.
- Locate executables with `Paths.executable`, never a hard-coded prefix.
- Ship desktop files in `macarchy/resources`; they are bundled into the app.
- Nothing here may require System Integrity Protection to be disabled.

## Style

Use British English, straight apostrophes and no em dashes in new prose.
Comments explain constraints and decisions; avoid repeating code or recording
volatile line counts. Use Swift 6 concurrency checks and the repository formatter.

Commit messages use `feat:`, `fix:`, `refactor:` or `docs:`.

## Errors and logging

Throw `ConfigurationError` with a sentence a person can act on. Use `try?` only
where absence is an expected, documented outcome. In the app, record command
results with `CommandLog.record`, notes with `note` and failures with `failure`.
Report partial application explicitly rather than as success.

## Interface help

Prefer contextual tooltips for secondary instructions over persistent explanatory
lines. Use `HelpTooltip` for help beside a group and `hoverHelp` for an individual
control. Keep wording brief and describe the action. Keep essential status, errors
and information needed to make a decision visible. Use the shared tooltip host so
wrapped text stays inside its bubble and above scrolling content.

## Configuration reference

### Existing dotfiles

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

### Ghostty

Your Ghostty config is never rewritten. Setup adds one line:

```
config-file = ?/Users/you/.config/macarchy/generated/ghostty.conf
```

It goes at the end of the last config file Ghostty loads, so theme colours win
and everything else is yours. No Ghostty? That step is skipped.

### What it changes

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

### Default shortcuts

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

### Do I need to disable SIP?

No. Everything Macarchy does works with System Integrity Protection on, using
yabai 7.1.25 or newer: tiling, rules, focusing and swapping windows, switching
desktops and moving windows between them.

yabai's optional *scripting addition* adds extras Macarchy does not rely on,
such as swapping whole desktops, window opacity and sticky windows. It requires
partly disabling SIP; follow
[yabai's guide](https://github.com/asmvik/yabai/wiki/Disabling-System-Integrity-Protection)
only if you want those. Setup health shows its status either way.

### Command line

The app includes a `macarchy` command, used by the startup files:

```sh
~/.config/macarchy/Macarchy.app/Contents/MacOS/macarchy doctor
```

`setup`, `uninstall`, `doctor`, `apply`, `theme <name|next|prev>`,
`wallpaper <theme> <path>`, `rules [toggle]`, `bar toggle` and `restore`.
Run it with no arguments for details.

### Themes

Eight themes ship with the app. A theme is a folder with a `theme.json` and a
Ghostty palette, optionally with wallpapers; Themes → Import adds your own.
Bundled themes do not include wallpapers; add your own images to a theme's
folder and pick them on the Themes page.

#### Neovim

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

#### Custom builds

A file in `~/.config/macarchy/bin` replaces the Homebrew copy of the same tool,
for example a patched `borders`.

### Uninstall

1. **Advanced → Restore original files** (or `macarchy uninstall`) puts back
   every file setup replaced and removes the ones it created.
2. Delete Macarchy.app, and `~/.config/macarchy` if you do not want your
   settings and themes.

### Reporting problems

**Report a problem** in the app prepares an issue with your Mac model, versions
and check results. Your name, username, computer name and home folder are
removed, and you see the whole report before anything is sent. Or
[open an issue](https://github.com/HarryRandall/macarchy/issues) directly.
