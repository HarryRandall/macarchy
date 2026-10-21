# Architecture

Macarchy has three Swift targets that share one implementation:

- **Macarchy** (`src/core`): settings, themes, setup and integrations.
- **App** (`src/desktop`): the native shell in `native` (lifecycle, windows,
  the switcher panel, the menu bar item and the web view bridge), and the
  SwiftUI settings window in `classic` for the panes not yet migrated.
- **CLI** (`src/cli`): the `macarchy` command, bundled inside the app.

The settings window and the theme switcher are drawn by a React interface in
`src/desktop/ui`, hosted in web views; see [the interface guide](interface.md).

`tools/build.sh` builds the interface and copies it to `Contents/Resources/ui`,
then copies `resources` into `Contents/Resources`, flat: `themes`, `sketchybar`
(the menu bar scripts and font), `skhd` (the default shortcuts), and `logo.svg`
and `AppIcon.icns` from `resources/app`. The bundle's `Info.plist` comes from
`packaging/macos`.

## One folder

Macarchy owns `~/.config/macarchy`:

| Path | Purpose |
|---|---|
| `settings.json` | Every preference: theme, layout, borders, menu bar, rules. Schema-versioned. |
| `themes/` | Installed themes. Bundled ones are copied in by setup and never overwritten. |
| `generated/` | Rendered from the active theme for other programs: Ghostty colours, bar colours, shell colours, Neovim colourscheme name. |
| `backups/` | Originals of every file setup replaced, with a manifest. Never pruned. |
| `snapshots/` | Rolling copies taken before each change, for undo. |
| `bin/` | Optional replacements for daemon executables. |
| `state/` | Scratch state for the menu bar scripts. |
| `Macarchy.app` | A link to the installed app. |

`MACARCHY_HOME` relocates everything for tests.

## Startup

yabai, skhd, SketchyBar and borders read their config from fixed paths, so
setup writes short startup files there. Each runs
`~/.config/macarchy/Macarchy.app/Contents/MacOS/macarchy startup <tool>`, which
reads `settings.json` and applies it, then keeps one `macarchy:keep yours`
region for the person's own commands. The app link means an updated or moved
app keeps working; the app repairs the link when it launches.

`skhdrc` is the exception: it stays the person's file, seeded with defaults.

## Setup and uninstall

`Setup.plan` lists every change without writing. `Setup.run` backs each target
up once, then adopts or replaces existing configuration, links the app,
installs themes and adds Ghostty's include line. `Setup.uninstall` restores the
backups and deletes files that did not exist before. Running setup again is
idempotent and never reseeds a file the person has edited.
`SetupSession` sequences setup, service startup and theme application, returning
partial failures with the results. Its theme application is injectable so tests
record desktop effects. `AdvancedConfiguration` resolves snapshot identifiers
from the store and owns maintenance operations. `DesktopServices` shares Secure
Input handling between the native status menu and React service controls; focus
hand-off is injected by the native host.

## Integrations

Executables are found with `Paths.executable`: `~/.config/macarchy/bin`, then
both Homebrew prefixes, then `PATH`. launchd labels are discovered from
`~/Library/LaunchAgents`. Commands run through `CommandRunner` with argument
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
