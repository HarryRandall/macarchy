# Plan: built-in instant Space switching

Status: steps 1 to 4 built on `feat/space-gesture` (5 November 2026); the
rest proposed. Quit the ISS app before trying a build: while it runs with
swipe override, it takes the app's swipes for its own, as it does ISSCli's.

## Why

Today two copies of InstantSpaceSwitcher (ISS) switch Spaces, and they do
not know about each other:

- ⌘1 to ⌘0 are the ISS app's own hotkeys.
- ⌘⇧1 to ⌘⇧0 run `switch_space_native.sh N move`, which moves the window
  with yabai, then `macarchy space N`, which starts `ISSCli`. That tool sends
  the swipe and stays running for 0.3 s while it settles.

The ISS app has swipe override on, and on macOS 27 another process's synthetic
swipe reaches its event tap looking like a real trackpad swipe. So it swallows
ISSCli's swipe and sends its own: two switchers doing one switch, which is the
glitch. Afterwards the app trusts its own guess of the current Space for 1 s
(`kPredictionTTL`), and the Dock ignores a swipe while the last one settles.
A quick ⌘2 after a move is therefore dropped instead of queued, because it never
reaches Macarchy's `SpaceSwitch` lock.

The fix is one switcher, living in the Macarchy app that is always running,
which every shortcut goes through. ISS is MIT licensed (copyright 2026
jurplel), so its switching core can be included with its notice.

## What we take from ISS

From `Sources/ISS` at a pinned upstream commit, trimmed to switching only:

| Keep | Why |
|---|---|
| `iss_post_dock_swipe`, `iss_perform_switch_gesture`, `iss_swipe_progress_for_phase` | The fake fast swipe that skips the slide |
| `iss_post_modern_dock_swipe` and `event_serialize.c` | macOS 27 accepts the swipe only with the raw IOHID payload written into the event |
| Mission Control and Exposé detection | A swipe while either is open must not be sent |

| Leave out | Why |
|---|---|
| Event tap and swipe override | The cause of the glitch; not needed to switch |
| Window carry (`window_drag.c`, `bridged_ops.c`, `window_focus.c`) | yabai already moves windows without SIP |
| Predictions, hotkeys, menu bar, settings, `ISSCli` | Macarchy owns these in Swift |
| Space info reading | `SpacesReading` already reads the same window server lists in Swift |

## Design

### C target

A new SwiftPM C target, `SpaceGesture`, at `src/space-gesture`, with
`include/SpaceGesture.h` exposing a few plain functions:

- `sg_can_post_events()` and `sg_request_post_events()`: Accessibility for
  posting events.
- `sg_switch(direction, steps)`: that many switch gestures back to back (three
  phases each, plus the macOS 27 companion event), as upstream jumps.
- `sg_overlay_open()`: Mission Control or Exposé is showing.
- The pure parts, for tests: swipe progress and sign, the event before
  posting and the macOS 27 payload.

The `Macarchy` target depends on it. The files keep jurplel's MIT header, and
a `README` beside them names the upstream commit and what was trimmed, so a
macOS change can be compared with upstream later.

### Swift switcher (`src/core/integrations/space-switching`)

`SpaceSwitcher`, an actor owning the only state:

- **Where we are heading.** The Space index last asked for, trusted while
  gestures are in flight, the way ISS's predictions are, so a burst never
  computes from an intermediate Space the window server reports mid-swipe.
- **One switch at a time, latest wins.** A press during a switch replaces the
  target; when the current hop lands, it carries on to the latest target and
  skips the ones in between. This is today's `SpaceSwitch` logic, moved from a
  file lock between processes to one actor in one process.
- **Landing.** Waits on `SpacesReading.currentSpaceIDs()` with the existing
  patience, instead of ISSCli's fixed 0.3 s.
- **Index to swipes.** yabai's global index maps to a display and a
  per-display position through `SpacesReading.indicesFromWindowServer()`.
  A target on another display, an unavailable gesture or an open overlay
  falls back to `yabai -m space --focus`, as now.
- **Move and follow.** `move(to:)` reads the focused window from yabai, sends
  `window <id> --space N`, switches, then focuses the window, all inside the
  same serial queue, so a following plain switch waits its turn.

Everything that touches the desktop is injected (gesture, Space reading,
yabai), like `SpaceSwitch` today, so tests run with fakes and
`DesktopIsolation` refuses real gestures.

### Who runs it

The app (`MacarchySettings`) runs the switcher. While it can post events, it
holds a lock on `state/space-switcher.lock`, the same pattern as
`WidgetHostPresence`.

`macarchy space N [--move]`:

1. Posts the bar's existing `spaceNotification`, as now.
2. If the app holds the switcher lock, posts a new distributed notification,
   `io.github.harryrandall.macarchy.space.switch`, with the index and the move
   flag, and exits. The app's observer hands it to `SpaceSwitcher`.
3. Otherwise runs the same `SpaceSwitcher` in its own process, with today's
   file lock between processes. Run from skhd, skhd's Accessibility covers it,
   so switching still works when the app is closed.

Starting the command takes a few milliseconds, so skhd stays the place
shortcuts are defined and the Shortcuts page keeps working unchanged.

### Shortcuts

- Default `skhdrc`: `ctrl + shift - N : macarchy space N --move`, replacing
  `move-window-to-space.sh`. Keep shipping the script for a release so
  existing files keep working, and have it call `macarchy space N --move`.
- The Shortcuts page recognises `macarchy space N --move` as "Move window to
  desktop N" (`shortcut-groups.ts`, `shortcut-presentation.ts` and tests).
- Your own `config/skhdrc` gets `cmd - N : macarchy space N` and
  `cmd + shift - N : macarchy space N --move` in place of the ISS hotkey note
  and `switch_space_native.sh`, done by hand once this lands. Setup never
  rewrites an edited `skhdrc`.

### Permissions and health

- The app needs Accessibility to post events. Check with
  `CGPreflightPostEventAccess` and ask with `CGRequestPostEventAccess` from
  setup, not at launch.
- Health replaces the InstantSpaceSwitcher row with "Instant Space switching":
  passed when the app can switch; otherwise it says switches go through skhd
  or slide with yabai, and how to fix it.
- Ad hoc rebuilds reset Accessibility; development builds should use
  `MACARCHY_SIGN_IDENTITY`, as CONTRIBUTING already says.

### Retiring ISS

- Remove `InstantSpaceSwitcher` from setup extras, Advanced and Doctor, and
  stop `AppDelegate` starting it.
- If ISS is installed, Health warns while it is running, since its hotkeys and
  swipe override still compete, and says to quit it. Macarchy never uninstalls
  it.
- Rewrite "Instant Space switching" in CONTRIBUTING, credit jurplel's MIT
  code in CREDITS.md, and update `docs/architecture.md`.

## Steps

Each step is its own commit, in an isolated worktree.

1. **Vendor the core.** Done. `SpaceGesture`, trimmed, with tests for the
   swipe progress and sign, both event forms, the payload's layout and that
   macOS keeps the appended field when it reads the event back.
2. **Switcher in core.** Done. `SpaceSwitcher` in
   `src/core/integrations/space-switching`, with its live desktop, and tests
   for bursts, move then a quick switch back, a press during the move, an
   overlay, no permission, a failed swipe, a missing Space, another display
   and a switch that never lands. Nothing calls it yet; `SpaceSwitch` and its
   tests stay until step 3 replaces them.
3. **App service and CLI hand-off.** Done. `SpaceSwitcherController` in the
   app holds `state/space-switcher.lock` while it may post events and takes
   `SpaceSwitchRequest` notices; `macarchy space N [--move]` hands over or
   switches itself through `SpaceSwitch`, which now switches with a
   `SpaceSwitcher` instead of ISSCli and can move a window too.
   `PresenceLock` is shared with the widget host's lock. An isolated run
   leaves every switch to its fake yabai.
4. **Permissions, Health, setup.** Done. The app asks for Accessibility
   after setup runs. Health's "Instant Space switching" row reads the
   switcher lock, so the app and `macarchy doctor` agree, and a second row
   warns while the ISS app runs. ISS is gone from setup's extras, Advanced and
   app launch; `InstantSpaceSwitcher` only checks whether it is running.
5. **Shortcuts and docs.** Defaults, Shortcuts page parsing, CONTRIBUTING,
   architecture. The interface's setup fixtures, mock and `SetupExtraId` still
   name ISS as an example extra; with `Setup.extras` empty the page hides the
   section, so drop them here, regenerating `tests/fixtures/bridge`.
6. **Try it on the desktop**, with your go-ahead and nobody else testing:
   fast bursts, ⌘⇧3 then ⌘2 at once, Mission Control open, a Space that does
   not exist, two displays, the app closed, and quitting ISS.

## Risks and checks

- **Private formats.** The macOS 27 payload and CGS calls are undocumented, so
  a macOS update can break them, as it can for ISS. If the gesture is
  unavailable, switching falls back to yabai and Health says so.
- **Dock wedging.** ISS notes that overshooting on macOS 27 can leave the Dock
  black until it times out. Never send more swipes than there are Spaces past
  the current one, and never start a hop before the last one lands.
- **FasterSwiper.** ISS's macOS 27 fields were taken from FasterSwiper's
  traces. Check its licence before shipping, in case any of its code came along.
- **Trackpad swipes.** Without swipe override, three-finger swipes slide as
  macOS normally does. Making those instant needs an event tap in the app,
  which is out of scope here.

## Open question

Do you use ISS's instant trackpad swipes? If so, add a later step that
intercepts the trackpad swipe in the app and sends it through
`SpaceSwitcher`, so there is still only one switcher.
