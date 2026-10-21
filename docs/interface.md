# Interface

The settings window and the theme switcher are React pages in native AppKit
windows. Swift owns everything that touches the desktop or the disk; React owns
presentation and interaction state. The menu bar item, and the settings pages
not yet migrated, are still SwiftUI.

## Pieces

| Path | What it is |
|---|---|
| `src/desktop/ui` | The React and TypeScript interface, built with Vite. Its own package: `package.json`, `pnpm-lock.yaml` and tool configs live here. |
| `src/desktop/ui/src/bridge` | The bridge contract (`protocol.ts`), the client, and a mock host for browser development. |
| `src/desktop/ui/src/components/ui` | Shared controls: buttons, switches, sliders, selects, segmented controls, tooltips, menus. |
| `src/desktop/ui/src/components/layout` | Page header, settings sections and rows. |
| `src/desktop/ui/src/shell` | The settings window's sidebar, top bar and page host. |
| `src/desktop/ui/src/features` | One folder per page or surface, with its previews and complex controls. |
| `src/desktop/native/web` | `WebSurface` (a web view and its bridge), `HostWebView` (title bar dragging), `AppScheme` (serves the bundled interface and wallpaper thumbnails). |
| `src/desktop/native/bridge` | The Swift mirror of the contract, the router, state snapshots and the broadcaster. |
| `src/desktop/native/window` | The React settings window, the classic window's AppKit host, and the window buttons both use. |
| `src/desktop/native/switcher` | The floating switcher panel and its global shortcut. |
| `src/desktop/classic` | The SwiftUI window, for panes that have not moved yet and for setup. |

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
`ThemeApplication`, as the CLI and the status menu do.

Events flow the other way through `window.macarchyBridge.receive`. A
document-start script queues any that arrive before the page's client starts.
`StateBroadcast` sends them whenever the models the status menu reads change,
and when `settings.json` changes on disk, so a theme switched from the CLI, the
status menu or the classic window shows up everywhere.

`protocol.ts` and `BridgeMessages.swift` describe the same shapes and must be
changed together.

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
`?fail=layout`, `?fail=layout-state`, `?source=saved` or `?setup` to see
failure and notice states; `window.macarchyMock` opens the switcher and pushes
changes.

Debug builds also read these, and release builds ignore them:

| Variable | Effect |
|---|---|
| `MACARCHY_UI_DEV_SERVER=http://localhost:5173` | Load the pages from the Vite server, for hot reload. |
| `MACARCHY_DEBUG_DRY_THEMES=1` | The switcher records theme and background choices instead of applying them, which would change the real wallpaper and appearance. |
| `MACARCHY_DEBUG_NO_SHORTCUT=1` | Skip ⌘⌃Space and `macarchy switcher`, which an installed copy would also answer. |

With `MACARCHY_HOME` and `MACARCHY_SEARCH_PATH` pointing at a temporary home
and fake tools, a debug build runs beside the installed app without touching
the desktop. Debug builds open their switcher on the distributed notification
`io.github.harryrandall.macarchy.debug.switcher`.

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

## Overview pages

Home, Setup health and Report a problem are React pages. Home is the new
window's default pane. The classic window restores an unmigrated selection,
falling back to Workshop while it remains classic. Workshop and Plugins links
on Home are labelled as previews.

Home reads `DesktopOverview` in core, without using another page's React store.
`home.changed` and `health.changed` invalidate read-only summaries after model
or settings changes and on window focus. A file fingerprint also detects theme,
shortcut and snapshot changes made outside the app. Slow health reads are
serialised and keep the previous findings visible while checking again.

`DiagnosticSnapshot` gathers the same Doctor checks and Diagnostics environment
as the classic pages did. Report keeps these facts for the page session and
prepares a redacted preview for each description. Native report actions accept
the preview's token, so copying and opening share precisely the displayed body;
a stale token is refused. `ProblemReport` prepares the issue URL and the long
report clipboard fallback. Clipboard, browser and Finder actions stay native
and are replaced by recorders in tests. Preparing or refreshing never writes
settings, reads logs or submits an issue.
