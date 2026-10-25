# Architecture

Macarchy has three Swift targets that share one implementation:

- **Macarchy** (`src/core`): settings, themes, setup and integrations.
- **App** (`src/desktop`): the native shell in `native` (lifecycle, windows,
  the switcher panel, the menu bar item, the web view bridge and the models
  behind each page).
- **CLI** (`src/cli`): the `macarchy` command, bundled inside the app.

The settings window and the theme switcher are drawn by a React interface in
`src/desktop/ui`, hosted in web views; see [the interface guide](interface.md).

`tools/build.sh` builds the interface and copies it to `Contents/Resources/ui`,
then copies `resources` into `Contents/Resources`, flat: `themes`, `sketchybar`
(the menu bar scripts and font), `skhd` (the default shortcuts), and `logo.svg`
and `AppIcon.icns` from `resources/app`. The bundle's `Info.plist` comes from
`packaging/macos`.

## One folder

Macarchy owns `~/Library/Application Support/Macarchy`:

| Path | Purpose |
|---|---|
| `settings.json` | Every preference: theme, layout, borders, menu bar, rules. Schema-versioned. |
| `config/` | The configs yabai, skhd, SketchyBar and borders run with. |
| `themes/` | Installed themes. Bundled ones are copied in by setup and never overwritten. |
| `widgets/` | Bar widgets people made or imported, one folder each; see [widgets](widgets.md). |
| `generated/` | Rendered from the active theme for other programs: Ghostty colours, bar colours, shell colours, Neovim colourscheme name. |
| `backups/` | Originals of the agents and Ghostty config setup changed, with a manifest. |
| `snapshots/` | Rolling copies taken before each change, for undo. |
| `bin/` | Optional replacements for daemon executables. |
| `state/` | Daemon logs and scratch state for the menu bar scripts. |
| `Macarchy.app` | A link to the installed app. |

`MACARCHY_HOME` relocates everything for tests. It and `MACARCHY_SEARCH_PATH`
also isolate the run from the desktop: `DesktopIsolation` lets launchd,
`defaults`, AppleScript, signals to running apps, `open` and the daemons run
only as fakes under the home or the search path, and refuses the wallpaper,
the bundled bar scripts and notifications to the running app, reporting them
as skipped. Test processes are isolated even without either variable. A
`MACARCHY_HOME` that is the account's own home does not isolate.

Earlier versions used `~/.config/macarchy`. `LegacyLayout` moves it on first
launch when it holds Macarchy's data and the new folder has no settings yet,
merging into a new folder something else created first (anything that clashes
is kept aside in `Macarchy before migration <date>` and Doctor reports it).
Bar scripts never create the new folder. The move leaves a link at the old path
that stays until uninstall, because earlier startup files, shortcuts and the
person's own scripts may still name it. Setup also rewrites old command paths
in the shortcuts and keep regions it carries over, so the link is a fallback.
Snapshot records are moved to the new paths, and restore maps any it missed.

## Startup

Macarchy runs yabai, skhd, SketchyBar and borders from its own LaunchAgents
(`io.github.harryrandall.macarchy.<tool>`), each started with its file in
`config/` (`yabai -c`, `skhd -c`, `sketchybar --config`, and bordersrc run
directly), so nothing is written where the tools look by default. `DaemonAgents`
writes the agents and switches off the ones the tools' installers made.
Starting a daemon reloads its job when the agent on disk no longer matches what
`launchctl print` reports. If Macarchy's job does not stay running and an
installer's job was running before, that one is loaded again and Macarchy's
agent moves to `state/agents` until the next start, so only one loads at login.

The yabai, SketchyBar and borders files are short startup files. Each runs
`macarchy startup <tool>` through the app link, which reads `settings.json` and
applies it, then keeps one `macarchy:keep yours` region for the person's own
commands. The app link means an updated or moved app keeps working; the app
repairs the link when it launches.

`skhdrc` is the exception: seeded with defaults, then the person's file.

SketchyBar sets `$CONFIG_DIR` and its working folder to the folder of the file
it starts with, resolving links, and passes them to every item script. A
person's own bar finds its plugins, colours and icons that way, so when setup
keeps one, the agent starts `~/.config/sketchybar/macarchy-sketchybarrc`, a
two-line launcher that execs `config/sketchybarrc`. The bar then runs
Macarchy's file with the folder it was written for, and SketchyBar still
watches that folder for changes. Setup backs the launcher up as absent, so
uninstall removes it, and Doctor reports it if it goes missing.

## Setup and uninstall

`Setup.plan` lists every change without writing. `Setup.run` writes the files
in `config/`, starting from the person's own configs when they choose to keep
them (those are read, never changed), links the app, installs themes, writes
the agents and adds Ghostty's include line, backing up the agents and Ghostty
config it changes. `Setup.uninstall` stops Macarchy's agents, restores the
backups and deletes what did not exist before; `Setup.returnServices` then
hands each tool back to its installer. Running setup again is idempotent and
never reseeds a file the person has edited.
`SetupSession` sequences setup, service startup and theme application, returning
partial failures with the results. The app and the `macarchy setup` and
`uninstall` commands all go through it; `--no-apply` runs the file steps only. Its theme application is injectable so tests
record desktop effects. `AdvancedConfiguration` resolves snapshot identifiers
from the store and owns maintenance operations. `DesktopServices` shares Secure
Input handling between the native status menu and React service controls; focus
hand-off is injected by the native host.

## Integrations

Executables are found with `Paths.executable`: Macarchy's `bin/`, then
both Homebrew prefixes, then `PATH`. launchd labels are discovered from
`~/Library/LaunchAgents`, Macarchy's own first. Commands run through `CommandRunner` with argument
arrays, a timeout and cancellation that also stops child processes.

Every integration is optional. Theme application skips tools that are not
installed and says so. Nothing requires System Integrity Protection to be
disabled; the yabai scripting addition is reported as an optional extra.

## Persistence

Settings writes lock across processes with a bounded wait, validate, snapshot
the previous version and replace atomically. Desktop changes take the desktop
lock so the app and command cannot interleave. Generated files record a hash;
a file edited outside its keep region is snapshotted and reported.

## Checks

`swift test` covers persistence, locking, process cancellation, skhd parsing and
rewriting, theme outputs, the shared theme collection and library, Neovim discovery,
rules, the menu bar editor, layout editing, border appearance editing, and the
bridge and web views against the built interface.
`corepack pnpm run check` in `src/desktop/ui` covers the interface.
`tests/integration/setup.sh` runs setup, a repeat setup and uninstall
in a temporary home against fake tools.
