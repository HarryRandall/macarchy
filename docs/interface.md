# Interface

The settings window and the theme switcher are React pages in native AppKit
windows. Swift owns everything that touches the desktop or the disk; React owns
presentation and interaction state. Only the menu bar item is still SwiftUI.

## Pieces

| Path | What it is |
|---|---|
| `src/desktop/ui` | The React and TypeScript interface, built with Vite. Its own package: `package.json`, `pnpm-lock.yaml` and tool configs live here. |
| `src/desktop/ui/src/bridge` | The bridge contract (`protocol.ts`), the client, and a mock host for browser development. |
| `src/desktop/ui/src/components/ui` | Shared controls: buttons, switches, sliders, selects, segmented controls, tabs, cards and rows, tooltips, menus. |
| `src/desktop/ui/src/components/charts` | Sparklines, line and bar charts, service rings and status dots, with keyboard-readable values. |
| `src/desktop/ui/src/components/layout` | Page chrome (top bar actions and page search), page header, settings sections and rows. |
| `src/desktop/ui/src/shell` | The settings window's sidebar, top bar, service status and logs panels, command palette, changelog route and page host. |
| `src/desktop/ui/src/features` | One folder per page or surface, with its previews and complex controls. |
| `src/desktop/native/web` | `WebSurface` (a web view and its bridge), `HostWebView` (title bar dragging), `AppScheme` (serves the bundled interface and wallpaper thumbnails). |
| `src/desktop/native/bridge` | The Swift mirror of the contract, the router, state snapshots and the broadcaster. |
| `src/desktop/native/window` | The React settings window, the classic window's AppKit host, and the window buttons both use. |
| `src/desktop/native/switcher` | The floating switcher panel and its global shortcut. |
| `src/desktop/classic` | The old SwiftUI window, which nothing opens now. `MenuBarModel` and its helpers still live here and back the Menu Bar page. |

Advanced and first-run setup are React pages. Before settings exist, setup
replaces the selected pane and previews `Setup.plan` before enabling Set up.
Advanced can reopen setup. Setup results remain visible until Done, including
service or theme failures after files were written. When setup stops partway,
`setup.run` still resolves, with the steps completed so far and the reason in
`failure` (an explicit null when it finished). Both restore actions and
stopping a service use the shared confirmation dialog; restarting a service
acts immediately.

## Loading

Packaged builds load `macarchy-app://ui/settings.html` and `switcher.html`,
which `AppScheme` reads from `Contents/Resources/ui`. `tools/build.sh` builds
the interface and copies `src/desktop/ui/dist` there, so the app needs neither
Node nor a server at runtime. A custom scheme rather than `file://` gives the
page an origin, which module scripts need, and lets the response carry a
content security policy.

Images are served from `macarchy-app://media/...`: theme backgrounds by theme
and path inside the theme, and the current wallpaper. The handler resolves
these itself and refuses anything outside a theme folder.

Windows stay hidden until their page calls `app.ready`, so they never open on
an empty frame. The switcher's page is loaded at launch and kept. Each opening
orders the panel in fully transparent, sends the page fresh state, and reveals
the panel once that state has been drawn: WebKit does not draw pages in
windows that are off screen, so rendering while hidden would show the previous
frame. Closing resets the page the same way before the panel is ordered out.

Both settings windows are AppKit windows the app opens itself. The classic
SwiftUI root view is hosted in one rather than in a SwiftUI `Window` scene,
which would open on its own at launch.

## Bridge

Requests are named, typed and asynchronous. The page posts
`{ method, params }` to the `macarchy` script message handler; Swift replies
with `{ ok: true, value }` or `{ ok: false, error: { code, message } }`. Each
surface registers only the methods it uses, and there is no general command or
shell method.

Handlers are thin. Layout calls `YabaiLayout` in `src/core`, which reads the
running daemon and applies edits through `SettingsApply`, the same serialised,
apply-then-save path every other setting uses. The switcher calls
`ThemeApplication`, as the CLI and the status menu do. It closes the panel
before applying a theme or background, so the panel never covers the desktop
as it redraws, then awaits the outcome. A failure reopens the panel with what
failed and why in `switcher.willOpen`, shown until dismissed or the next
opening.

Themes reads the shared native catalogue through `ThemeCollection` in `src/core`.
Its named `themes.setDark`, `themes.setColour`, `themes.setColourscheme` and
`themes.reset` operations save through `ThemeLibrary`; edits apply to the desktop
only when Apply or Reapply is chosen. `themes.apply` and
`themes.chooseWallpaper` use the same injectable `ThemeActions` as the switcher.
`themes.importFolder` and `themes.exportFolder` open native panels through an
injectable `ThemePanels`; filesystem destinations never cross the bridge.
`themes.reveal` validates the installed theme before showing it in Finder.
The page re-reads on `themes.changed`, preserving queued field edits. Colours
preview locally while dragging and save once the change settles. Reset asks
first, and every save snapshots the previous `theme.json`.

Events flow the other way through `window.macarchyBridge.receive`. A
document-start script queues any that arrive before the page's client starts.
`StateBroadcast` sends them whenever the models the status menu reads change,
and when `settings.json` changes on disk, so a theme switched from the CLI, the
status menu or the classic window shows up everywhere.

`protocol.ts` and `BridgeMessages.swift` describe the same shapes and must be
changed together.

The shell reads `shell.getState`: the selected pane, sidebar and appearance
preferences, the app's version and each service with its state.
`shell.setPreferences` also stores the appearance (System, Light or Dark) and
sets the window's `NSWindow.appearance`, so the native title bar matches; the
page mirrors it with `data-theme` on the root. `shell.getLog` returns the
command log that the logs panel shows, `shell.clearLog` empties it, and
`shell.logChanged` invalidates it once per burst. `shell.restartAll`,
`shell.revealSettings` and `shell.quit` back the brand menu.

Advanced uses named `advanced.getState`, `restartService`, `stopService`,
`rebuild`, `restoreSnapshot`, `repairAddition` and `restoreOriginals` requests.
`setup.getPlan`, `setup.run` and `setup.openAccessibility` serve setup.
`advanced.changed` carries a fresh reading; `advanced.invalidated` asks for a
read after shared service, snapshot or theme changes. The shell's service pill
uses the same native daemon monitor.

The contract is checked against shared fixtures.
`src/desktop/ui/src/bridge/fixtures.ts` holds example cases for every method
and event, typed against `BridgeMethods` and `BridgeEvent`, so `tsc` fails when
one has no fixture or a fixture no longer fits. Across a type's cases, give
every nullable field one null and one value, and use every union value.
`fixtures.test.ts` checks that `tests/fixtures/bridge/methods.json` and
`events.json` match them; after a contract change run
`UPDATE_BRIDGE_FIXTURES=1 corepack pnpm vitest run src/bridge/fixtures.test.ts`
in `src/desktop/ui` and commit the JSON. `BridgeContractFixtureTests` builds
both surfaces' routers as the app does, requires their method names to equal
the fixture keys, decodes every `params`, and requires every `result` and
event to decode and re-encode to the same JSON, nulls included, so result
types are `Codable`. A new event also needs a line in that test's event table.

## Design

The settings window follows the Studio design, whose working mockup lives in
`src/desktop/ui/src/components/gallery/options/studio` (development only, not
linted or bundled). `styles/index.css` holds its colour, type, radius and motion
roles for light and dark; components use the role names, never raw values. The
interface accent is Studio's indigo; the active theme's colour is
`--theme-accent`, used only where a page previews the theme itself.

Page actions go to the top bar through `PageHeader` or `TopBarActions`, and a
page that filters its items calls `usePageSearch`, which turns the top bar's
search field into that page's filter; ⌘K opens the command palette. Where a
page draws something the app cannot provide yet, its data lives in a typed
`<feature>-mock.ts` beside it and each use is marked with a `Mock:` comment, so
it can be found and replaced.

## Development

```sh
cd src/desktop/ui
corepack pnpm install
corepack pnpm dev
```

With the dev server running, `/src/components/gallery/` shows every shared
component in each variant and state, in light and dark, with accent
extremes; it is not part of the production build.

In a browser, the page runs against the mock host in `bridge/mock.ts`. Add
`?fail=layout`, `?fail=layout-state`, `?fail=switcher`, `?source=saved` or `?setup` to see
failure and notice states; `window.macarchyMock` opens the switcher and pushes
changes.

Debug builds also read these, and release builds ignore them:

| Variable | Effect |
|---|---|
| `MACARCHY_UI_DEV_SERVER=http://localhost:5173` | Load the pages from the Vite server, for hot reload. |
| `MACARCHY_DEBUG_DRY_THEMES=1` | Applying a theme, from any surface or the command, logs the wallpaper, appearance and Ghostty and Neovim refreshes instead of making them. Everything else applies as usual. |
| `MACARCHY_DEBUG_NO_SHORTCUT=1` | Skip ⌘⌃Space and `macarchy switcher`, which an installed copy would also answer. |

`tools/run.sh` builds a debug copy and opens it beside the installed app with
the last two, a fresh temporary home and fake yabai, skhd, SketchyBar, borders,
launchctl and defaults. Macarchy's files stay in that home and its commands
reach the fakes. Setting either `MACARCHY_HOME` or `MACARCHY_SEARCH_PATH`, even
to an empty value, makes a run isolated (`Paths.isolated`). An isolated run
takes launchctl and defaults only from the search path, so service restarts and
stops are recorded in `launchctl.log` in the temporary home and the Borders
corner radius is kept in a file there, not the global setting. It never repairs
the real sudoers rule for the scripting addition, keeps the selected pane and
sidebar in the `io.github.harryrandall.macarchy.development` preferences suite,
opens windows centred without saving their frames or restoring them, and never
repoints the app link. Debug builds never repoint it either. Each run stops only
the copy the previous run started. Debug builds open their switcher on the
distributed notification `io.github.harryrandall.macarchy.debug.switcher`.

`corepack pnpm run check` runs type checking, oxlint, Prettier and Vitest.
The web view tests in `tests/desktop/web` load the built `dist` through the
real scheme handler, with a temporary home and a fake yabai; build the
interface first. They are skipped when `dist` is missing, unless
`MACARCHY_REQUIRE_UI_TESTS=1`, as in CI. Setting `MACARCHY_UI_SNAPSHOTS` to a
folder renders each state of both pages there as PNGs for review.

## Adding a page

1. Build the page in `src/desktop/ui/src/features/<page>` from the shared
   components, and add it to the shell's page host.
2. Add its requests and events to `protocol.ts` and `BridgeMessages.swift`,
   and register handlers that call shared operations in `src/core`.
3. Add the pane to `Pane.migrated`, so the classic window sends it to React.
4. Delete the SwiftUI pane and anything only it used.

## Rules

The Rules page uses `WindowRuleSettings` in the core to read saved floating
apps and custom rules alongside live external rules. Custom rules apply before
saving through `WindowRules.commitCustom`; floating edits read the latest list
inside the same desktop lock. Failed applies or saves replay the previous rules
and report a failed replay explicitly. Opening and refreshing only read. When
yabai cannot be reached, the page shows the saved rules with the reason and
turns editing off, because rules apply through yabai before they are saved.

The bridge exposes `rules.getState`, `rules.addApplication` (the native application
picker), `rules.removeFloating`, `rules.saveCustom` and `rules.removeCustom`.
`rules.changed` publishes saved state after edits and external settings changes;
`rules.unavailable` reports unreadable external changes. React keeps open editor
drafts separate from incoming state. Saving enables a custom rule; removing it
asks first, then stops applying it. External rules remain read-only.
Every edit starts from the list the page shows, so apps that float only
through a live `float_persist_` rule written the way Macarchy writes them
(`app=^<escaped name>$`, no title) are adopted into the saved list rather than
dropped. Other `float_persist_` rules show as external and are never removed.
Toggling the focused window rolls back like any other edit. An editor opened on a saved rule sends `existing: true`,
and saving it fails if the rule was removed elsewhere instead of recreating it.

## Borders

Borders uses named requests: borders.getState, borders.apply and
borders.pickApplication. BorderSettings in the core reads preferences, the
global macOS corner override and active theme colours. BorderEdit applies the
complete appearance before saving it, and writes theme colours only after
settings are saved. A failed apply or save restores the previous corner
override and saved settings, and reports a failed restore explicitly. The page
keeps manual drafts separate and coalesces live edits over 180 ms. Controls stay
enabled while an apply runs; later edits apply next. borders.changed and themes.changed keep
it current without replacing an unsaved draft. A draft for a previous theme
must be discarded before editing the new theme.

## Overview pages

Home, Setup health and Report a problem are React pages. Home is the new
window's default pane. Workshop and Plugins are labelled as previews wherever
they appear.

Home reads `DesktopOverview` in core, without using another page's React store.
`home.changed` and `health.changed` invalidate read-only summaries after model
or settings changes and on window focus. A file fingerprint also detects theme,
shortcut and snapshot changes made outside the app. Slow health reads are
serialised and keep the previous findings visible while checking again.

`DiagnosticSnapshot` gathers the same Doctor checks and Diagnostics environment
as the classic pages did. Report collects these facts when the page opens or
the person presses Refresh (`report.prepare` with `refresh: true`), sharing a
collection already running; draft edits reuse the last collection. It
prepares a redacted preview for each description. Native report actions accept
the preview's token, so copying and opening share precisely the displayed body;
a stale token is refused. `ProblemReport` prepares the issue URL and the long
report clipboard fallback. Clipboard, browser and Finder actions stay native
and are replaced by recorders in tests. Preparing or refreshing never writes
settings, reads logs or submits an issue.

## Menu Bar

The Menu Bar page edits a draft of the bar and applies it in one go.
`menuBar.getState` reads SketchyBar and the saved configuration through
`MenuBarModel`; `menuBar.apply` takes the whole list back, in order, with each
item's zone and visibility, and the bar's height, position and padding.
`MenuBarEdits` lays that over the saved configuration, so colours, spacing and
other authored details the page does not show survive. The bar's own items can
only be hidden. Items made on the page are text, spacers and commands; a
command runs through `sh` every `interval` seconds and its output becomes the
label. Their ids are `macarchy.` and a lower-case suffix, and Swift refuses any
other new id.

## App menu

Search, Show Logs, Back and Forward in the app menu send `shell.shortcut` to
the page, which runs them as its own keys do. A menu key equivalent can reach
AppKit before the page, so the page ignores a menu shortcut that repeats the
key it has just handled.

## Shortcuts

The Shortcuts page reads the person's skhdrc through `SkhdShortcuts` in the
core. Its named bridge operations are `shortcuts.getState`, `shortcuts.validate`,
`shortcuts.rebind`, `shortcuts.disable`, `shortcuts.reset` and
`shortcuts.openConfiguration`. Opening and refreshing never seed the file.
Writes check the loaded revision, snapshot the original, preserve custom lines
and restart skhd. A failed restart is reported separately from a successful save.
Only an explicitly confirmed reset replaces commands with bundled defaults.

The focused React recorder captures keydown events. Swift validates the chord
and renders its skhd spelling and key caps. macOS may intercept system shortcuts
before they reach WebKit. `shortcuts.changed` and `shortcuts.unavailable` events
report external file changes; an open recording is retained and a stale edit
must be reopened before saving. The broadcaster checks the selected skhdrc
once a second, including symlinks and the `~/.skhdrc` fallback.

Browser development supports `?fail=shortcuts` and `?fail=shortcuts-state`.
