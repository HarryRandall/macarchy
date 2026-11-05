# Contributing

Macarchy configures a daily-use desktop. Keep development builds separate from
installation, preserve unrelated work, and commit focused, reviewable changes.
Read [the architecture guide](docs/architecture.md) for the shared app and CLI design.

## Build and install

Requires an Apple Silicon Mac with macOS 26 or later, Xcode 27,
[Homebrew](https://brew.sh) and Node.js 22.12 or later (for building the
interface; pnpm comes through Node's corepack, or from `brew install pnpm` on
Node 25 and later, which no longer include corepack). Open Xcode once to finish
installing its components.

```sh
git clone https://github.com/HarryRandall/macarchy.git
cd macarchy
brew bundle
brew install swiftlint
./tools/build.sh release
```

The build creates `.build/artifacts/Macarchy.app` and does not install it.
To try a change, `./tools/run.sh` opens a debug build beside the installed app
in a temporary home with fake daemons and stops only the copy it started last.
[The interface guide](docs/interface.md#development) lists what it does not
isolate. To install, close Macarchy first and make sure no other session is editing or
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

Run `corepack pnpm run check` and `corepack pnpm run build` in `src/desktop/ui`,
then `swift build`, `swift test`, `./tools/lint.sh` and
`tests/integration/setup.sh` and `tests/integration/plugins.sh`. CI runs the same. The web view tests in
`swift test` need the built interface; without it they are skipped locally and
fail in CI. Tests must use temporary
homes (`MACARCHY_HOME`), fake tools (`MACARCHY_SEARCH_PATH`) and must never alter
the running desktop. Use Xcode 27's `swift-format`; CI installs SwiftLint through Homebrew.

Beyond the upstream rules, the interface lint loads a local plugin,
`src/desktop/ui/lint/macarchy.js`, adapted from rules T3 Code uses:

- Every lint or type suppression gives a reason (`require-suppression-reason`);
  `@ts-ignore` is banned.
- No native `title` tooltips; use `Tooltip` (`no-native-title-tooltip`).
- A scroll area that centres content reserves its gutter
  (`require-centered-scroll-gutter`).
- `:has()` in an arbitrary variant is anchored to a selector (`no-unscoped-has`).
- `ResizeObserver` goes through `observeResize` (`no-raw-resize-observer`).
- No dividers, unlinked TODOs, test narration, commented-out code or comments
  that repeat the name below (`no-low-value-comments`).
- In tests: no timeouts or unexplained skips, no wall clock, no real-time waits
  without fake timers, no polling loops, no tests declared in loops and no DOM
  emulators. DOM behaviour is tested in WKWebView from Swift.
- Features and the shell never import `*Variants` recipes from
  `components/ui`; styling stays with the primitives.

SwiftLint adds `no_fixed_sleep_in_tests` (a fixed sleep needs a disable comment
with a reason, outside the polling helpers) and `no_process_name_kill`.
`tools/lint.sh` also fails if anything in `tools` or `tests/integration` stops
or signals processes by name.

## Structure and naming

Directories use lowercase names with hyphens between words. Swift filenames
match their primary type. Keep conventional filenames such as `Package.swift`
and `Info.plist`. Do not add empty folders for speculative future features.

The App and CLI targets use the shared Macarchy target. Themes, configuration
and integration behaviour belong in `src/core`; the command is in `src/cli`.
In `src/desktop`, `native` holds the app lifecycle, windows, switcher panel,
menu bar item, web view bridge and the models behind each page; `ui` holds
the React interface. Add targets or protocols only when a concrete dependency
or test needs them. Prefer small concrete types over generic frameworks.

React owns presentation and interaction state. Filesystem access, desktop
changes and persistence stay in Swift, reached through named bridge methods
whose handlers call `src/core`. [The interface guide](docs/interface.md)
covers the bridge, loading and development.

In `src/desktop/ui`, files use kebab-case and components PascalCase named
exports. Controls in `components/ui` own their look through `variant` and
`size`; features choose variants and add only layout classes.

| Path | Contents |
|---|---|
| `src/core` | `settings`, `filesystem`, `processes`, `setup`, `diagnostics`, `integrations`, `themes`, `widgets` |
| `src/desktop` | `native`, `ui` (React) |
| `tests` | `core`, `desktop`, `integration` and `fixtures` |
| `resources` | `app` (logo and icon), `themes`, `widgets` (built-in bar widgets), `integrations/sketchybar` (the app font), `integrations/skhd`, `launchers` (yabai and SketchyBar start launchers), `plugins` (Neovim configuration and launcher) |
| `packaging/macos` | `Info.plist` |

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
- Everything Macarchy owns lives in `~/Library/Application Support/Macarchy`,
  through `Paths`. Quote paths in shell: the folder name has a space.
  Write outside it only where a tool requires a fixed location, and only after
  `Setup` has backed the file up.
- Every integration is optional. Detect it, skip it when it is missing, and say
  so; never fail a whole operation because one tool is absent.
- Locate executables with `Paths.executable`, never a hard-coded prefix.
- Ship desktop files in `resources`; `tools/build.sh` copies them into the
  app's `Contents/Resources`.
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
lines. Keep wording brief and describe the action. Keep essential status, errors
and information needed to make a decision visible. In React, sections and rows
take a `help` tooltip and controls use the shared `Tooltip`.

## Configuration reference

### Existing dotfiles

Setup asks whether to start from existing yabai and skhd configs. It only
reads them; Macarchy runs the tools with its own copies.

- **Keep mine and add Macarchy.** Your shortcuts stay as they are. Plain
  top-level `yabai -m config` lines move into Macarchy's Layout page; every other
  line, including anything inside loops and conditionals, is kept word for word.
- **Start fresh.** Macarchy starts from its defaults.

The menu bar is always Macarchy's widgets, so a `sketchybarrc` of your own is
not used either way. Your own files are left as they are.

### Menu bar

The bar shows widgets, arranged on the Menu Bar page: Spaces on the left, and
network, memory, GPU, CPU, battery and the clock on the right to begin with.
See [widgets](docs/widgets.md) to make your own.

Menu Bar → Bar controls the bar height, side padding and screen edge gap, plus
the gap, inner side padding and box height shared by widgets. Top and bottom
padding adjusts the bar height around those boxes. A widget's own
side padding overrides the shared value. Spaces and other grouped widgets keep
their internal spacing and height under their own settings.

Commands in the keep region of `config/sketchybarrc` run after the widgets are set up.

The app keeps the widgets up to date, so it opens at login; turn that off
under **Advanced → Open at login**. While it is not running, readings keep
their last values and the clock still keeps time.

Earlier versions ran either a bundled bar or your own. Setup moves either onto
widgets once, after a snapshot, and says what happened to each item: the
bar's own Spaces, network, memory, GPU, CPU, battery and clock become the
built-in widgets in the same places, command items become scripted widgets in
`widgets/`, and hidden items go. Your own bar no longer runs, because it
removed every item, widgets included; its commands are kept word for word in
`config/own-bar-before-widgets.sh`, and anything no widget replaces is named.

Theme changes recolour the bar in place, and write the colours to
`generated/bar-colours.sh` for scripts of your own.

### Ghostty

Your Ghostty config is never rewritten. Setup adds one line:

```
config-file = ?/Users/you/Library/Application Support/Macarchy/generated/ghostty.conf
```

It goes at the end of the last config file Ghostty loads, so theme colours win
and everything else is yours. No Ghostty? That step is skipped.

### What it changes

Everything Macarchy owns lives in **`~/Library/Application Support/Macarchy`**:
settings, themes, the tools' configs, history and files rendered from the
active theme. The tools' configs are in its `config/` folder:

| File | Contents |
|---|---|
| `yabairc` | Hands over to Macarchy, plus a region for your own commands |
| `sketchybarrc` | Same |
| `bordersrc` | Same |
| `skhdrc` | Your shortcuts, seeded with defaults (or from your own) on first setup |

Outside the folder it only writes:

| File | Contents |
|---|---|
| `~/Library/LaunchAgents/io.github.harryrandall.macarchy.<tool>.plist` | Starts each tool at login with its config. The tool's own agent is switched off and backed up |
| Ghostty's existing config, or its native Application Support config | One `config-file` line, if you use Ghostty |
| `~/.zshenv` and the active `.zshrc` | One line adding the app's bundled commands to new zsh sessions; uninstall removes only that line |

The yabai and SketchyBar launchers ship inside Macarchy.app. Their paths must
contain no spaces, so install the app in `/Applications/Macarchy.app`. Setup
updates the service definitions to use those bundled launchers. After that,
the old `~/.config/macarchy` launchers are no longer needed. Do not remove them
while the installed service definitions still refer to them.

### Cleaning up after an upgrade

Earlier versions left files in `~/.config/yabai`, `skhd`, `borders` and
`sketchybar`. **Advanced → Clean up old configuration** (or
`macarchy cleanup`, then `macarchy cleanup --apply`) shows what it will do
first, then:

- moves your own scripts and the files they use into
  `~/Library/Application Support/Macarchy/scripts`, keeping their names and
  permissions, and points your shortcuts, yabai region and the scripts
  themselves at the new places;
- points the zsh, Neovim and Ghostty lines that read through
  `~/.config/macarchy` at Application Support, and removes the old link once
  nothing needs it;
- deletes the startup files, backup copies and old bar Macarchy no longer
  reads, and restarts the tools whose files changed.

A file something it cannot change still uses, such as a LaunchAgent of your
own, stays where it is and is listed with the reason. Everything it deletes or
changes goes into one zip in `backups` first, apart from named pipes and
sockets a running program made, which go with their folder;
`macarchy cleanup --restore <archive>` puts it all back. A file it rewrote
that you have edited since stays as you left it, with the earlier version
beside it as `<name>.before-cleanup`. Your own bar's
commands, kept in `config/own-bar-before-widgets.sh`, name that archive, since
they relied on `~/.config/sketchybar`.

Edits outside a file's `macarchy:keep` region are snapshotted and reported, not
silently lost.

### Default shortcuts

**Control** (⌃) moves between desktops and windows. Change any of them on the
Shortcuts page.

| Shortcut | Action |
|---|---|
| ⌃ Return | Open a terminal |
| ⌃⇧ S | Screenshot an area to the clipboard |
| ⌃ Arrows | Focus window |
| ⌃⇧ Arrows | Swap window |
| ⌃ 1–9, 0 | Switch to desktop 1–10 |
| ⌃⇧ 1–9, 0 | Move window to desktop 1–10 and follow |
| ⌃ T | Float or tile the window, remembered per app |
| ⌃ F | Fill the screen |
| ⌃ J / L | Flip split / rotate and rebalance |
| ⌃ = / - | Grow / shrink |
| ⌃⇧ = / - | Next / previous theme |
| ⌃⇧ Space | Show or hide the menu bar |
| Media keys | Play, pause and skip in Spotify |
| ⌘ Q | Quit the app that owns the focused window |
| ⌘ W | Also quits Messages, TablePlus and Obsidian |
| ⌘⇧ M | Open the Brave profile picker |

### Instant Space switching

Macarchy switches Spaces with no slide, by sending the Dock a trackpad swipe
fast enough that there is nothing to animate. The swipe is trimmed from
[InstantSpaceSwitcher](https://github.com/jurplel/InstantSpaceSwitcher) (MIT)
and lives in `src/space-gesture`; nothing else needs installing.

`macarchy space <number>` goes to a Space and `--move` takes the focused
window with it. The shortcuts run those, and the app does the switching:
one at a time, then straight to the last desktop pressed, so pressing
quickly never stops on one in between, and a switch pressed just after a
move waits its turn. The app needs Accessibility for this and asks after
setup. Until it has it, each shortcut switches on its own with skhd's
permission. A Space on another display, or one picked while Mission
Control is open, goes through yabai and slides. Health says which is in
use.

Earlier versions installed InstantSpaceSwitcher. If its app still runs, its
own hotkeys and trackpad swipe override compete with Macarchy's switching,
and Health says to quit it.

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
"$HOME/Library/Application Support/Macarchy/Macarchy.app/Contents/MacOS/macarchy" doctor
```

`setup`, `uninstall`, `doctor`, `cleanup`, `apply`, `theme <name|next|prev>`,
`wallpaper <theme> <path>`, `rules [toggle]`, `bar toggle` and `restore`.
Run it with no arguments for details.
`setup` does what the app's setup does: it writes the files, starts the
services and applies the theme. `setup --no-apply` only writes the files.

### Themes

Eight themes ship with the app. A theme is a folder with a `theme.json` and a
Ghostty palette, optionally with wallpapers; Themes → Import adds your own.
Bundled themes do not include wallpapers; add your own images to a theme's
folder and pick them on the Themes page.

#### Neovim

Neovim's configuration and plugin lockfile ship in `resources/plugins/neovim`.
Setup seeds an editable copy in
`~/Library/Application Support/Macarchy/plugins/neovim/config/nvim` and
preserves it on later runs. Plugin downloads, state and cache live beside
`config` under `data`, `state` and `cache`. None needs `~/.config` or `~/.local`.

The app bundles an `nvim` launcher. Setup adds one line putting the app's
commands on `PATH` to `~/.zshenv` and the `.zshrc` zsh reads (in `ZDOTDIR` when
that is set); uninstall removes only that line, and a file left empty. Bash and
fish are not changed. Open a new terminal after setup; `command -v nvim` should
point inside Macarchy.app. The launcher runs `bin/nvim` from Application
Support when there is one, otherwise the first Neovim on `PATH`. It points the
XDG directories at Macarchy's folders, and `environment.lua` beside it puts the
person's own values back once the configuration is read, so terminals, git and
language servers started from the editor see the usual settings.

To migrate an existing installation, run `./tools/migrate-plugins.sh` before
setup. It moves existing Neovim configuration and data into managed storage,
keeping a conflicting destination in Macarchy's `backups`. It also moves an
existing XDG Ghostty folder to Ghostty's native Application Support folder,
unless that already exists. It checks every source first and refuses linked
folders before moving anything. Python tools Mason installed get pip's
`/bin/sh` trampoline, since a `#!` line cannot hold the new path's space;
any other Mason tool whose interpreter moved is listed for reinstalling. Existing editor
sessions should be closed first.

Macarchy writes the active colourscheme to `generated/nvim-colorscheme`;
the bundled Neovim configuration reads it. Keep configuration and the lockfile
in Git; downloaded plugins and editor state can be recreated. Personal changes
to the installed copy must be copied back to the repository before pushing.

#### Custom builds

A file in Macarchy's `bin/` folder replaces the Homebrew copy of the same tool,
for example a patched `borders`.

### Uninstall

1. **Advanced → Restore original files** (or `macarchy uninstall`) stops
   Macarchy's agents, gives each tool back the agent and files it had and
   removes Ghostty's include line. After a cleanup it also puts your scripts
   and old folders back where your original files expect them; a moved script
   you edited since stays in `scripts` as well.
   Macarchy also stops opening at login.
2. Delete Macarchy.app, and `~/Library/Application Support/Macarchy` if you do
   not want your settings and themes.

### Reporting problems

**Report a problem** in the app prepares an issue with your Mac model, versions
and check results. Your name, username, computer name and home folder are
removed, and you see the whole report before anything is sent. Or
[open an issue](https://github.com/HarryRandall/macarchy/issues) directly.
