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
| `backups/` | Originals of the agents and Ghostty config setup changed, with a manifest. |
| `scripts/` | The person's own scripts their shortcuts and keep regions run. |
| `snapshots/` | Rolling copies taken before each change, for undo. |
| `bin/` | Optional replacements for daemon executables. |
| `state/` | Daemon logs, startup records and the widget host's lock. |
| `Macarchy.app` | A link to the installed app. |

`MACARCHY_HOME` relocates everything for tests. It and `MACARCHY_SEARCH_PATH`
also isolate the run from the desktop: `DesktopIsolation` lets launchd,
`defaults`, AppleScript, signals to running apps, `open` and the daemons run
only as fakes under the home or the search path, and refuses the wallpaper
and notifications to the running app, reporting them as skipped. Test processes are isolated even without either variable. A
`MACARCHY_HOME` that is the account's own home does not isolate.

Tests never run the person's scripts: `DesktopIsolation` refuses anything in
`scripts/` or the tools' old folders except `bash -n` or `zsh -n`.

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
in Application Support.

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
would. The fake yabai and SketchyBar run their file as `sh -c <path>`, as the
real ones do, so a path sh would split fails there too.
