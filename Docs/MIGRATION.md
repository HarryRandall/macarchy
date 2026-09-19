# Migrating the live desktop into the app

The goal: this app becomes the thing that owns the desktop's configuration, and
the shell layer it grew out of goes away. This is a plan for doing that without
breaking a machine that is in daily use.

## Decisions taken

| Question | Decision |
|---|---|
| `theme-switch` (995 lines) | **Reimplement in Swift**, then delete it |
| Raycast theming | **Drop** |
| cursor-agent reload | **Drop** |
| Hotkeys | **Keep skhd**; app owns binding data and generates `skhdrc` |
| Login-time apply | **Generated rc shims** — launchd orchestration unchanged |
| Hand-edits to generated files | **Drift detection, not read-only** (see below) |
| sketchybar items | **In scope** — items become importable packages |

Dropping Raycast and cursor-agent removes 21 lines outright. ~975 remain to port.

## The rule

**Strangler, never dual ownership.** For each surface: build the new path, run
it alongside the old one and diff the output, cut over, then *delete* the old
path. At no point do two things write the same file — that was the `bordersrc`
problem, and at this scale it would be much worse.

Every phase ends at a verification gate. If the gate fails, the phase reverts;
it does not get patched forward.

## Port sizing

Measured per surface from `theme-switch`:

| Surface | Funcs | Lines | Notes |
|---|--:|--:|---|
| borders | 7 | 204 | largely done already in `BordersModel` |
| nvim | 2 | 163 | colorscheme mapping table |
| macOS accent | 9 | 145 | nearest-Apple-accent matching; fiddly, `NSColor` makes it easier in Swift |
| core | 2 | 113 | theme resolution, cycling |
| btop | 3 | 86 | writes theme file + hot-reloads running instances |
| sketchybar | 3 | 77 | |
| shell env | 1 | 72 | |
| wallpaper | 3 | 49 | delegates to `set-wallpaper` |
| ghostty | 2 | 32 | colour + palette emit |
| colour utils | 1 | 26 | hex normalising; already partly in `Color+macarchyHex` |
| ~~Raycast~~ | 1 | 8 | dropped |
| ~~cursor-agent~~ | 1 | 13 | dropped |

---

## Phase 0 — Safety rails

Nothing else starts until these exist. None of it is migration work; all of it
is what makes migration survivable.

1. **Version control the borders fork.** `~/projects/jankyborders-local` has no
   `.git` at all. Commit pristine v1.9.0, then the patch on top, so the diff is
   inspectable and a future upstream release can be rebased onto.
2. **Commit this repo.** Still entirely untracked.
3. **`macarchy doctor`** — one command that asserts the desktop is healthy:
   four daemons up, borders answering, the current theme resolving, wallpaper
   set, `skhdrc` parsing. Run before and after every phase. This is the gate.
4. **Snapshot/restore in the app** — versioned, pruned to 20. Already planned;
   now it is load-bearing.

**Gate:** `doctor` passes, and a deliberate rollback from a snapshot restores a
working desktop.

## Phase 1 — Finish the theme package

Mostly done; close it out.

- Themes pane reads the manifest only — no `theme.env` reads remain
  *(currently inconsistent: the pane's header says `theme.json` but the rows
  below still render env values)*
- Write-through: editing writes `theme.json`, `theme.env` is regenerated from it
- Import / export / reset-to-default, with defaults shipped in the bundle

**Gate:** round-trip a theme out and back in; `doctor` passes.

## Phase 2 — Generated rc shims

Establishes the contract everything later depends on: **app writes JSON → a
generator writes the rc file → launchd runs it, unchanged.**

Order by ascending risk:

1. `bordersrc` — smallest, and the app already owns most of its inputs
2. `yabairc` — config and rules are data; signals and the `sudo yabai --load-sa`
   line are not, and stay hand-authored in a preserved block
3. `sketchybarrc` — bar geometry and the item list. Item *definitions* become
   packages (Phase 3a); the plugin **scripts** they carry are code and are
   never rewritten by the generator, only referenced.

Each generated file carries a `# generated` header and a preserved region for
the hand-written parts.

**On protecting generated files:** not `chmod -w`. Read-only files fight your
editor, break quick recovery, and still do not stop a determined write — they
just make the failure confusing. Instead the app stores a hash of what it last
wrote. Before regenerating, it re-hashes the file on disk: if it differs, the
file was hand-edited, so the app snapshots the edited version and warns rather
than silently discarding the change. Hand-editing keeps working; it just cannot
vanish without telling you.

**Gate:** reboot. The desktop comes up identical, from generated files only.

## Phase 3a — Sketchybar items as packages

Items should be buildable in the UI and importable as JSON, the same way themes
are — that is what makes a shared library of them possible.

There are currently 4 item files (battery, calendar, spaces, system_metrics),
and **all four are script-backed**: each is a set of declarative sketchybar
properties plus a shell script that produces its live data. So an item package
is two things, with very different trust levels.

```json
{
  "schema": 1,
  "name": "battery",
  "position": "right",
  "properties": {
    "icon": "􀋨",
    "update_freq": 5,
    "padding_left": 0,
    "background.border_width": 0
  },
  "subscribe": ["system_woke", "power_source_change"],
  "script": "plugins/battery.sh"
}
```

**The trust boundary is the point.** A theme is pure data and can be imported
safely. An item that ships a script is importable *code* that runs every few
seconds. So:

- Items with no `script` are **declarative** — import freely, build entirely in the UI.
- Items with a `script` are **scripted** — import shows the script for review and
  requires explicit confirmation. Never run on import, only after the user agrees.
- The UI labels which kind an item is, always.

Build order: read existing items into the format → item inspector (edit
properties, no scripting) → builder for new declarative items → import/export →
scripted-item review flow.

This is also the substrate for browsing a shared library later: a theme and an
item become the same kind of thing — a folder with a manifest.

## Phase 3b — Port theme-switch

One surface at a time, easiest first to build confidence in the harness, with
the riskiest last. For each: implement in Swift → run old and new against all
8 themes → diff every output file → delete the bash function.

1. ghostty (32) — smallest real surface, proves the diff harness
2. colour utils (26) — mostly exists
3. sketchybar (77)
4. shell env (72)
5. btop (86) — includes signalling running processes
6. nvim (163) — big but a pure mapping table
7. macOS accent (145) — nearest-accent matching; `NSColor` should beat the bash
8. borders (204) — largely done, so it lands late and cheap
9. wallpaper (49) — **last**, see below

**`set-wallpaper` is not ported.** It encodes genuinely hard-won behaviour —
desktoppr for the current Space, direct `Index.plist` rewriting for the others,
osascript fallbacks — and the failure mode is a grey desktop, which has bitten
this machine before. The app keeps invoking it as a helper. Revisit only once
everything else is done.

**Gate per surface:** byte-identical output across all 8 themes, then `doctor`.

Phases 3a and 3b are independent and can be done in either order.

## Phase 4 — Hotkeys

- Parse `skhdrc` into structured bindings (86 of them, grouped by the section
  comments already present)
- Editor UI with a key recorder
- Generate `skhdrc` from the binding data

`skhd` keeps doing global key capture — it is good at it, and reimplementing key
capture buys nothing.

**Gate:** generated `skhdrc` is semantically identical; all 86 fire.

## Phase 5 — Consolidate state

Fold the loose state files into app-owned storage:

- `.current` → app state
- `.backgrounds.json` → each theme's own `theme.json`
- `.nvim-colorscheme`, `.shell-env` → generated outputs, not state
- `float_state.json` → app state, surfaced by the Rules pane

This is also when `~/.config/themes` stops being a symlink, because nothing
hard-codes that path any more.

## Phase 6 — Retire

Delete, in this order, each only once nothing references it:

`theme-switch` → Raycast extension → `~/.config/macarchy` →
`~/.local/state/macarchy` → the `~/.config/themes` symlink

## Risks

| Risk | Mitigation |
|---|---|
| Wallpaper goes grey (has happened before) | `set-wallpaper` not ported; `wallpaper-baseline` folded into `doctor` |
| A generated rc file loses a hand-written line | Preserved regions; reboot gate in Phase 2 |
| Borders fork diverges from upstream | Phase 0 git init; SHA-256 of the base is already recorded |
| macOS 27 Space-switching workaround forgotten | Already surfaced in the Advanced pane |
| Port drifts from bash behaviour | Diff harness per surface; byte-identical output required before deletion |
| App becomes required for a working desktop | Login stays launchd + rc shims; the GUI is never in the boot path |

## Open questions

- **Scripted-item sandboxing.** Reviewing a script before import is a speed
  bump, not a security boundary — a reviewed script still runs unconfined every
  few seconds. Worth deciding whether that is acceptable for personal use
  (probably yes) before any library of shared items exists.
- **The bar itself**: sketchybar stays a daemon. If the app ever drew the bar,
  that is a separate project, not part of this migration.

## Resolved

- *Generated files*: drift detection by hash, not read-only. See Phase 2.
- *sketchybar items*: in scope, as packages. See Phase 3a. The 21 plugin
  scripts remain programs the app references but never authors.
