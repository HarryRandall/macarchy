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
then copies `resources` into `Contents/Resources`, flat: `themes`, `widgets`
(the built-in bar widgets), `sketchybar` (sketchybar-app-font, which the
Spaces widget draws apps with), `skhd` (the default shortcuts), `launchers`
(the yabai and SketchyBar start launchers), `plugins` (the seed Neovim
configuration and its launcher), and `logo.svg` and `AppIcon.icns` from
`resources/app`. The `nvim` launcher is also copied to `Contents/MacOS`. The bundle's `Info.plist` comes from
`packaging/macos`.

## One folder

Macarchy owns `~/Library/Application Support/Macarchy`:

| Path | Purpose |
|---|---|
| `settings.json` | Every preference: theme, layout, borders, menu bar, rules. Schema-versioned. |
| `config/` | The configs yabai, skhd, SketchyBar and borders run with. |
| `themes/` | Installed themes. Bundled ones are copied in by setup and never overwritten. |
| `plugins/neovim/` | Editor configuration, downloaded plugins, state and cache. Configuration is seeded from the app bundle. |
| `widgets/` | Bar widgets people made or imported, one folder each; see [widgets](widgets.md). |
| `generated/` | Rendered from the active theme for other programs: Ghostty colours, bar colours, shell colours, Neovim colourscheme name. |
| `backups/` | Originals of the agents and Ghostty config setup changed, with a manifest, and the archives cleaning up writes (`old-configuration-<date>.zip`). |
| `scripts/` | The person's own scripts their shortcuts and keep regions run, moved here by cleaning up. |
| `snapshots/` | Rolling copies taken before each change, for undo. |
| `bin/` | Optional replacements for daemon executables. |
| `state/` | Daemon logs, startup records and the widget host's lock. |
| `Macarchy.app` | A link to the installed app. |
| `migration.json` | What moving an earlier version's folder did, until setup reports it. |

`MACARCHY_HOME` relocates everything for tests. It and `MACARCHY_SEARCH_PATH`
also isolate the run from the desktop: `DesktopIsolation` lets launchd,
`defaults`, AppleScript, signals to running apps, `open` and the daemons run
only as fakes under the home or the search path, and refuses the wallpaper
and notifications to the running app, reporting them as skipped. Test processes are isolated even without either variable. A
`MACARCHY_HOME` that is the account's own home does not isolate.

Earlier versions used `~/.config/macarchy`. `LegacyLayout` moves it on first
launch when it holds Macarchy's data and the new folder has no settings yet,
merging into a new folder something else created first (anything that clashes
is kept aside in `Macarchy before migration <date>` and Doctor reports it).
Bar scripts never create the new folder. The move leaves a link at the old path
that stays until the person cleans up (below), because earlier startup files,
shortcuts and the person's own scripts may still name it. When the old path is the person's own
link, as dotfiles make it, the folder it leads to is copied instead, and the
link and that folder are left as they are; Doctor reports the copy left behind.
Setup also rewrites old paths in the shortcuts and the yabai, SketchyBar and
borders keep regions it carries over, so the link is a fallback. A rewrite
follows the shell's quoting (`OldPathScanner`) and is kept only when the result
still parses with `bash -n`; otherwise the text stays as written and the report
says so. Snapshot records are moved to the new paths, and restore maps any it
missed. The first command after an upgrade usually makes the move unseen, so
`move` leaves `migration.json` saying what it did; the setup screen, Doctor and
setup's report show it, and setup clears it.

## Cleaning up

Earlier versions also left startup files, backups and launchers in the
tools' own folders, `~/.config/yabai`, `skhd`, `borders` and `sketchybar`,
where people keep scripts their shortcuts run. Cleaning up is explicit:
`macarchy cleanup` prints the plan, `--apply` carries it out, and Advanced →
Clean up old configuration shows the same plan behind a confirmation.
`OldConfiguration.plan` only reads. It classifies each entry of those
folders: Macarchy's startup files, launchers, backup copies, empty folders
and the bar SketchyBar ran before can go; anything else is the person's own
and moves to `scripts/`, with its name and permissions, so the folders can go
entirely. References to what moves are pointed at the new places in the
shortcuts, the startup files, the person's zsh and bash startup files and the
moved scripts themselves. Each rewritten command or file must still parse
(`bash -n`, or `zsh -n` for zsh) or what it runs stays put. Anything else that uses an entry keeps it in place:
a LaunchAgent, Vim script, a widget, a file that stays, a path inside single
quotes, or a folder named as a whole. The link at `~/.config/macarchy` is
removed only once nothing reads through it: zsh and
shell paths go through `OldPathScanner`, Neovim Lua strings that hold only a
path and Ghostty `config-file` lines are pointed at Application Support, and
anything else that still names it keeps the link.

`OldConfiguration.apply` replans under the desktop lock, zips everything it
will delete or change, with a manifest, into `backups/` and checks the zip
reads back before changing anything, snapshots the configs it rewrites, then
moves, rewrites, removes the unused link and old launchers, and deletes. A failure before that says nothing was changed.
The zip is written and read with `ditto`, which keeps links, permissions and
extended attributes. Named pipes, sockets and devices cannot be archived:
they are left out of every copy, recorded in the manifest as skipped and
deleted with their folder. A pid file in a folder that goes, naming a process
that runs a script from inside that folder, is a helper the old bar left
running, and it is stopped; any other pid is reported. Deleting walks what the
archive holds, so anything that appeared after archiving stays and is
reported. It restarts skhd, yabai, SketchyBar or borders when their file or
launcher changed, through `Setup.startService`. `restore` refuses before
changing anything when a path it would put back is in use again; otherwise it
puts every file and the link back, removes the moved copies that were not
edited since (a moved folder is compared by a hash of its whole tree),
rewrites the agents and restarts the daemons. A rewritten file edited since
cleaning up is kept, and the archived version goes beside it as
`<name>.before-cleanup`. Doctor shows a warning while there is something to
clean up.

Uninstall reads every cleanup archive before restoring setup's backups, then
puts back what cleaning up moved or deleted wherever the backups left nothing,
leaving out Macarchy's launchers, and removes the moved copies nobody edited.
The person's original files then find their scripts and folders where they
were. A person's own bar kept in `config/own-bar-before-widgets.sh` names the
archive holding `~/.config/sketchybar`, which it relied on.

Tests never run the person's scripts: `DesktopIsolation` refuses anything in
`scripts/` or the tools' old folders except `bash -n` or `zsh -n`, and the
integration test points the owner's scripts' Homebrew paths at fakes and
runs with a PATH that has no Homebrew in it.

## Startup

Macarchy runs yabai, skhd, SketchyBar and borders from its own LaunchAgents
(`io.github.harryrandall.macarchy.<tool>`), each started with its file in
`config/` (`skhd -c`, bordersrc run directly, and yabai and SketchyBar through
launchers, below), so nothing is written where the tools look by default.
`DaemonAgents` writes the agents and switches off the ones the tools'
installers made.
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

yabai and SketchyBar run their config paths through an unquoted shell command.
Their tiny launchers now ship in the app's `Contents/Resources/launchers`, and
their agents name them where setup found the app, since the app link's path
has a space. Install the app in `/Applications/Macarchy.app` so those paths
have no spaces, and run setup again after moving it. Setup refuses a copy that
is translocated, on a mounted disk image or in `.build`. The SketchyBar
launcher gives the bar `~/.config/sketchybar` as `$CONFIG_DIR` and working
folder while that folder exists, so commands kept from an earlier bar still
find their files. Each launcher quotes the path to the real config
in Application Support. New setup does not create `~/.config/macarchy`.
Earlier launchers remain compatibility inputs for cleanup and uninstall only.

`macarchy startup <tool>` records the pid launchd reports for the daemon's
job in `state/startup/<tool>`. Doctor compares it with the copy running now,
so a daemon that started without running its file reads as a failure, not as
running. It also fails an agent whose start file is missing or has a space in
its path, as agents written before the launchers do until setup runs again.

## Menu bar

The bar is widgets only. `macarchy startup sketchybar` sets up the bar itself
through `BarLook` (geometry from settings, the theme's bar and text colours,
sketchybar-app-font and item defaults), then replays the saved bar
(`BarCommands`) and fills each widget in once. A bar never saved is
`BarConfiguration.widgetDefault`, which setup saves on a new install.
`sketchybarrc` runs startup first and the person's keep region after it.

The app's `WidgetHost` keeps the widgets up to date, so the first launch after
setup registers the app as a login item (`LoginItem`, through
`SMAppService.mainApp`), once; Advanced can turn it off, and that sticks.
Debug builds, isolated runs and test processes never register, and uninstall
unregisters it (`OpenAtLogin`). While the host runs it holds a lock on
`state/widget-host.lock` (`WidgetHostPresence`), trying again every half
minute while something else holds it. Clock items ask
SketchyBar to run `macarchy widget fallback` every half minute, which returns
at once while the lock is held and otherwise updates that clock, so a bar
without the app shows its last readings and the right time. Theme changes
repaint the bar and the widget items in place, and the host restarts when the
theme in settings changes.

Earlier versions saved `bundledBar`: true for Macarchy's bundled bar, false
for a person's own sketchybarrc. The key now stays among the settings'
unknown keys until setup moves the bar onto widgets (`Setup+Bar`,
`WidgetMigration.moveBar`), and while it is there the app opens setup and
Doctor warns. Setup snapshots settings and sketchybarrc, turns the bar's own
items into built-in widgets in place and command items into scripted widgets,
drops hidden items and names anything else, then removes the key. A person's
own bar built every item in its keep region, starting by removing them all,
so the region moves to `config/own-bar-before-widgets.sh` and no longer runs;
Macarchy's earlier bar keeps its region. Until then, startup shows a bundled
bar the widgets it is about to move onto, and leaves an own bar as it was.

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

## Space switching

One switcher serves every Space shortcut. `SpaceSwitcher`
(`src/core/integrations/space-switching`) sends the instant Dock swipe from
the `SpaceGesture` C target on the display under the pointer, and falls back
to `yabai -m space --focus` for another display, while Mission Control or
App Exposé is open, or without permission to post events. Requests run in
the order they arrive; one made while a switch lands only records its Space,
and the switcher goes on to the latest once it lands, working each switch
out from the Space showing so a burst never overshoots.

The app runs it (`SpaceSwitcherController`) and holds
`state/space-switcher.lock` while it may post events. `macarchy space N
[--move]` posts a `SpaceSwitchRequest` notice while that lock is held;
otherwise it switches itself through `SpaceSwitch`, which coordinates
presses across processes with `state/space-switch.lock` and the
`space-target` file. Health reads the same lock, so the app and the command
agree.

With `trackpadSwipes` on in settings, the app also runs an event tap
(`TrackpadSwipes`, `SwipeOverride.c`) that catches the trackpad's sideways
Dock swipe and calls `SpaceSwitcher.step`, holding the rest of the gesture
back so the Dock never animates it. On macOS 27 the app's own swipes come
back looking like the trackpad's, so it counts them as it posts them and
lets that many through. Only the app catches swipes; while it is closed they
slide as macOS normally does. An isolated run never posts events and leaves every switch to its
fake yabai.

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
in a temporary home against fake tools, and starts each agent as launchd
would. `tests/integration/upgrade.sh` upgrades a copy of the owner's earlier
layout and checks their own bar ends on widgets with nothing lost. The fake yabai and SketchyBar run their file as `sh -c <path>`, as the
real ones do, so a path sh would split fails there too.
