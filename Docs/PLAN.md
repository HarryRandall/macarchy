# Macarchy Settings — Plan

## 1. What this is

A native macOS app that replaces dotfile-editing for the running desktop stack:

| Daemon | Managed by | What the app controls |
|---|---|---|
| yabai | `com.asmvik.yabai` | gaps, padding, layout, placement, mouse, float rules |
| borders | `homebrew.mxcl.borders` | width, visibility, blacklist (colours stay theme-owned) |
| sketchybar | `homebrew.mxcl.sketchybar` | bar geometry, item visibility |
| skhd | `com.koekeishiya.skhd` | binding viewer (editor later) |
| `theme-switch` | — | theme selection + authoring |

Two surfaces: a **menu bar extra** for instant theme switching, and a **settings
window** for everything else.

Non-goals: reimplementing `theme-switch`, touching sketchybar plugin logic,
owning Space switching, anything requiring `sudo`.

---

## 2. The architectural spine

One rule drives everything:

> **Read live from the daemons. Persist to env files. Never parse rc scripts.**

The rc files (`yabairc`, `sketchybarrc`, `bordersrc`, `skhdrc`) are real shell
with comments, conditionals, signal handlers, and `source` chains. Round-tripping
them while preserving that is where this kind of project dies. So we don't.

### Three layers

**Layer 1 — `DaemonClient`.** Async `Process` wrapper per CLI. Every setting
knows how to read and write itself through it:

```
yabai -m config window_gap          -> "8"     (read)
yabai -m config window_gap 12                  (write, applies instantly)
borders width=6.0                              (write)
sketchybar --bar height=37                     (write)
```

Verified against the running stack: **yabai and sketchybar both read back.**
`yabai -m config <key>` with no value returns it (`window_gap` -> `8`,
`layout` -> `bsp`). `sketchybar --query bar` returns full JSON, and
`sketchybar --query <item>` does the same per item. `yabai -m rule --list` returns
the rule set as JSON.

**Only borders is write-only** — it has no query verb, so the settings store is
authoritative for it alone. Everywhere else the UI hydrates from the live daemon
and the store is just persistence, which means the GUI can never drift out of
sync with what's actually running.

**Layer 2 — `SettingsStore`.** Owns `~/.config/macarchy/settings.env`, a
generated `KEY=value` file with a "do not edit by hand" header. The rc files
source it the way `bordersrc` already sources `theme.env`. The app only ever
writes key=value lines — never shell logic.

**Layer 3 — SwiftUI `@Observable` view models**, one per pane.

### Setting descriptors

Each setting is declared once, not scattered across UI and persistence:

```swift
struct Setting<Value: Codable & Equatable> {
    let id: String                       // "window_gap"
    let envKey: String?                  // "MA_WINDOW_GAP" (nil = live-only)
    let domain: Domain                   // .yabai / .borders / .sketchybar
    let read: (DaemonClient) async throws -> Value?
    let apply: (Value, DaemonClient) async throws -> Void
    let validate: (Value) -> Bool
}
```

Panes render from arrays of these. Adding a setting is one declaration plus one
row, never a new persistence path.

### Apply semantics

Sliders fire continuously. So:

- **On change** → debounce 80ms → `apply` (live, daemon only, no disk write)
- **On commit** (editing ended / field blur) → write `settings.env`, snapshot backup

That gives instant visual feedback while dragging without thrashing the disk.

---

## 3. Fixing `bordersrc` first

This is prerequisite work, not part of the app. `bordersrc` currently has **two
owners**: it's a hand-authored script with env-sourcing and fallback logic, *and*
`theme-switch`'s `write_borders_config()` rewrites it wholesale. Every edit races
the generator.

**Resolution — split keys by ownership:**

| Owner | Keys | File |
|---|---|---|
| Theme | `BORDER_ACTIVE`, `BORDER_INACTIVE`, `BORDER_ANIMATION_*` | `theme.env` |
| Settings | `BORDER_WIDTH`, `BORDERS_VISIBLE`, `BORDERS_BLACKLIST` | `settings.env` |

Colour is a theme's job. Geometry and behaviour are the user's. No key appears in
both files, so precedence never comes up.

Steps: move `BORDER_WIDTH` out of all 8 `theme.env` files → have `bordersrc`
source `settings.env` after `theme.env` → delete `write_borders_config()` from
`theme-switch` and have it just restart the service.

Same collapse applies to sketchybar, which currently has three overlapping colour
paths (`theme.env` → `theme.sh` → `colors.sh` defaults). Only 2 of 8 themes set
`SKETCHYBAR_*`, so the other 6 silently land on the teal defaults in `colors.sh`.
Make `theme.sh` the single generated source and strip the fallbacks.

---

## 4. GUI design

### Window

`NavigationSplitView` with a source list sidebar — deliberately System
Settings-shaped, since that's the idiom being replaced. Fixed ~820×580, not
resizable below content.

```
┌────────────────┬──────────────────────────────────────┐
│ ● Themes       │  Layout                              │
│ ▣ Layout       │  ──────────────────────────────────  │
│ ▢ Borders      │  Layout mode    [ BSP        ⌄ ]     │
│ ▤ Menu Bar     │  Split type     [ Auto       ⌄ ]     │
│ ⌘ Shortcuts    │  Placement      [ Second child ⌄ ]   │
│ ⚑ Rules        │                                      │
│ ⚙ Advanced     │  Gaps & Padding                      │
│                │  Window gap     ───●────────  8 px   │
│                │  ☑ Link all padding                  │
│                │  Padding        ───●────────  8 px   │
│                │                                      │
│                │  Mouse                               │
│                │  Modifier       [ ctrl       ⌄ ]     │
│                │  Follows focus  ( ) off              │
│                │                                      │
│                │             [ Revert ]  [ Reload ]   │
└────────────────┴──────────────────────────────────────┘
```

Conventions across every pane:

- **`Form` with `.formStyle(.grouped)`** — native inspector look for free
- **Slider + numeric field side by side** — drag for feel, type for precision
- **No Save button.** Changes are live. A footer shows "Applied · 2s ago", and
  Revert restores the last snapshot.
- **Inline validation.** If a daemon rejects a value, the row goes red with the
  daemon's own stderr as the message. Nothing is persisted on rejection.

### Panes

**Themes** *(the centrepiece)*
Grid of theme cards, each showing its wallpaper thumbnail, accent swatch, and
name; current theme ringed. Selecting applies via `theme-switch <name>`.
Right pane edits the selected theme's `theme.env`: colour wells for
`BORDER_ACTIVE` / `SKETCHYBAR_*` / `FIREFOX_ACCENT`, a text field for
`NVIM_COLORSCHEME`, a dark-mode toggle, and a wallpaper picker backed by the
theme's `backgrounds/` directory.

Colour needs a two-way converter — borders and sketchybar want `0xAARRGGBB`,
`FIREFOX_ACCENT` wants `#RRGGBB`. The descriptor carries the format per key.

**Layout** — yabai, as sketched above.

**Borders** — width slider, visibility toggle, blacklist as a token field with an
app picker. Colours are read-only here with a "set in Themes" link, enforcing the
ownership split.

**Menu Bar** — bar geometry hydrated from `sketchybar --query bar` (height,
position, padding, blur, colour), then an item checklist.

Note the mismatch: there are **10 item definition files** but **28 live runtime
items**, because `spaces.sh` alone expands into `space.1`...`space.10` plus
`space_labels_updater`. Group the checklist by *source file*, not by runtime item,
or the pane shows ten near-identical Space rows. Per-item detail comes from
`sketchybar --query <name>`. Plugin *logic* is never touched.

**Rules** — table of per-app float rules. Two sources to merge:
`float_state.json` is a flat JSON array of app names (currently 9: Desk View,
Docker Desktop, FaceTime, Photo Booth, QuickTime Player, Raycast, Screen Sharing,
System Settings, Tailscale), while `yabai -m rule --list` returns richer objects
with `index` / `label` / `app` / `title`. The pane unions them keyed on app name,
showing which source each row came from.

Add-row uses a real app picker (`NSOpenPanel` scoped to `/Applications`) and
generates the anchored regex itself — beats hand-writing `app="^System Settings$"`.

**Shortcuts** — read-only table of all 86 skhd bindings, parsed into
`(modifiers, key, command, section)`, grouped by the section comments already in
`skhdrc`, with search and a rendered key-cap view. Editing is v2 via a
`# BEGIN managed` / `# END managed` block.

**Advanced** — daemon status (running/stopped + restart per daemon via
`launchctl kickstart` on the user agent), backup browser, and an **Active
Workarounds** list surfacing things like `switch_space_macos27.sh` and the
`TEMPORARY (2026-09-16)` note at `skhdrc:55` — currently buried in comments where
they're easy to forget.

### Menu bar extra

`MenuBarExtra` in `.menu` style: the 8 themes with a checkmark on current, a
divider, wallpaper submenu for the current theme, then Settings… and Restart All
Daemons. This is what retires the Raycast extension — and with it an entire
Node/TypeScript build pipeline (`ray build`, eslint, prettier, `node_modules`)
that existed to render a list and shell out to `theme-switch`.

---

## 5. Safety

The wallpaper store once reached 809 unpruned backups, so backups are a feature,
not an afterthought.

- Every commit-write snapshots affected files to
  `~/.local/state/macarchy/snapshots/<ISO8601>/`
- **Pruned to the last 20**, enforced on write
- Advanced pane browses and restores snapshots
- Validate-before-persist: daemon error → surface stderr, revert the control, write nothing

Also worth doing while we're here: clear the existing cruft — 7 stale timestamped
dirs in `~/.local/state/macarchy/backups/`, `yabairc.backup-mission-control-20260917`,
3 `.backup-20260917` sketchybar plugins, and three empty dirs (`generated/`,
`lib/apply/`, `state/themes/`).

---

## 6. Toolchain

**Swift Package Manager**, not an Xcode project — no `.pbxproj` merge pain, and
it stays legible to editors and agents.

```
Package.swift
Kit/                 # Core / Stack / Theme / Config
CLI/
Settings/            # App / Features / Shared
Themes/              # shipped default manifests
Scripts/build_app.sh
Docs/
```

`bundle.sh` wraps `swift build -c release` into a proper `.app` and signs it with
a **self-signed Keychain certificate** — not ad-hoc. Ad-hoc signatures change
every rebuild, so macOS treats each build as a new app; a stable identity avoids
that. The app itself needs no Accessibility permission (the daemons hold it), so
there's no TCC dance.

---

## 7. Build order

Each step is independently useful and ships something working.

1. **Unpick `bordersrc`** (§3). Prerequisite — it defines how every pane persists.
2. **`DaemonClient` + `SettingsStore` + Layout pane.** Proves query → live-apply →
   persist → revert end to end. Everything after is more of the same.
3. **Themes pane + menu bar extra.** Biggest daily win; retires Raycast.
4. **Borders + Menu Bar panes.** Mostly declarative once step 2 exists.
5. **Rules pane.** Needs the app picker and `float_state.json` merge.
6. **Shortcuts viewer.** Needs the skhdrc parser.
7. **Advanced pane.** Daemon status, snapshot browser, workarounds list.

---

## 8. Risks

| Risk | Mitigation |
|---|---|
| ~~Xcode license unaccepted~~ | Resolved 2026-09-19. Swift 6.4, target arm64-apple-macosx27.0.0. |
| `sudo yabai --load-sa` in `yabairc` | App never invokes sudo. Restart only via `launchctl kickstart` on the user agent. |
| macOS 27 Space-switching breakage | App does not own Space switching. Surfaced read-only in Advanced. |
| borders has no query verb | Settings store is authoritative for borders alone; yabai and sketchybar hydrate live. |
| `theme-switch` is 995 lines of load-bearing bash | Treated as a black-box backend. Never reimplemented, only invoked. |
