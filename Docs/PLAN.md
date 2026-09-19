# Macarchy Settings — Plan

The single planning document. `CONTRIBUTING.md` holds the working rules;
this holds the architecture, the migration, and the things that have already
bitten us.

## What this is

A native macOS app that takes over configuration of a desktop stack —
**yabai, JankyBorders, SketchyBar, skhd** — from a pile of shell scripts,
chiefly a 969-line `theme-switch`.

| Daemon | launchd label | What the app controls |
|---|---|---|
| yabai | `com.asmvik.yabai` | gaps, padding, layout, placement, mouse, float rules |
| borders | `homebrew.mxcl.borders` | width, visibility, blacklist (colours stay theme-owned) |
| sketchybar | `homebrew.mxcl.sketchybar` | bar geometry, item visibility |
| skhd | `com.koekeishiya.skhd` | binding viewer (editor later) |

Two surfaces: a **menu bar extra** for instant theme switching, and a
**settings window** for everything else.

This runs on a **daily driver**. It is not a sandbox. Breaking the desktop
means breaking the machine someone is working on. That is why every phase
ends at a gate, and why a failed gate reverts rather than gets patched forward.

Non-goals: touching sketchybar plugin *logic*, owning Space switching, porting
`set-wallpaper`, anything requiring `sudo`.

---

## The architectural spine

> **Read live from the daemons. Persist to env files. Never parse rc scripts.**

The rc files (`yabairc`, `sketchybarrc`, `bordersrc`, `skhdrc`) are real shell
with comments, conditionals, signal handlers and `source` chains.
Round-tripping them while preserving that is where this kind of project dies.
So we don't.

**Verified against the running stack:** yabai and sketchybar both read back.
`yabai -m config <key>` returns its value, `sketchybar --query bar` returns
JSON, `yabai -m rule --list` returns the rule set. **Only borders is
write-only** — it has no query verb, so `settings.env` is authoritative for it
alone. Everywhere else the UI hydrates from the live daemon, so the GUI cannot
drift from what is actually running.

Three layers:

1. **`Desktop`** — one folder per program, plus `Support/` for plumbing.
   `Sendable`, no UI imports. Shared by the app and the `macarchy` command.
2. **`settings.env`** — a generated `KEY=value` file the rc shims source. The
   app only ever writes key=value lines, never shell logic.
3. **SwiftUI `@Observable` models**, one per pane.

### Apply semantics

Sliders fire continuously, so:

- **On change** → debounce 80ms → apply (live, daemon only, no disk write)
- **On commit** (editing ended) → write `settings.env`, snapshot first

Instant feedback while dragging, without thrashing the disk.

---

## Layout

```
Desktop/          one folder per program the desktop runs
  Ghostty/        GhosttyConfig — palette inlining, the first ported surface
  Skhd/           SkhdConfig, SkhdBinding — skhdrc parser
  Theme/          Theme — a theme as portable data
  Launchd/        Daemon, DaemonState
  Support/        CommandRunner, Paths, EnvFile, GeneratedFile,
                  SettingsEnv, SnapshotStore, SettingKey, StackBackend
Settings/         the SwiftUI app — one folder per pane
  App/            SettingsApp, RootView, AppModel, Pane, StatusMenu,
                  CommandLog, ConsoleBar, DaemonMonitor
  Themes/ Borders/ MenuBar/ Layout/ Rules/ Shortcuts/ Advanced/
  Controls/       shared view components
  Support/        Color+Hex, RCGenerator
macarchy/         the `macarchy` command, installed to ~/.local/bin
Themes/           the 8 shipped manifests — the reset-to-default baseline
Tests/Desktop/    mirrors the Desktop subsystems
Tests/Fixtures/   reference.sh is the original shell, kept for diffing
Scripts/          build_app.sh · doctor.sh (THE GATE) · test.sh · lint.sh · run.sh
```

`Desktop/Yabai/`, `Desktop/Borders/`, `Desktop/Sketchybar/` and
`Desktop/System/` arrive when `StackBackend` is dissolved into per-tool types;
it is parked in `Support/` until then.

On the machine:

```
~/.config/macarchy-settings/   themes/, settings.env, snapshots/, generated.json
~/.config/themes               SYMLINK into the above (shell still hard-codes it)
~/.local/bin/macarchy          the command
~/.local/bin/theme-switch      the 969 lines still to port
~/.local/bin/macarchy-borders  the patched JankyBorders fork
~/projects/jankyborders-local  its source, under git — see square-borders.md
```

Backups of the pre-migration state live in
`~/.local/state/macarchy-settings-migration/`.

---

## Decisions taken

| Question | Decision |
|---|---|
| `theme-switch` | **Reimplement in Swift, then delete it.** Not a black box. |
| Raycast theming | **Drop** |
| cursor-agent reload | **Drop** |
| Hotkeys | **Keep skhd**; app owns binding data and generates `skhdrc` |
| Login-time apply | **Generated rc shims** — launchd orchestration unchanged |
| Hand-edits to generated files | **Drift detection by hash, not read-only** |
| sketchybar items | **In scope** — items become importable packages |
| `set-wallpaper` | **Never ported.** The app invokes it. |

---

## State right now

`doctor` 35 passed / 0 failed. `test.sh` 20 tests green. ~5,000 lines of Swift.

**Working panes:** Themes, Borders, Menu Bar, Layout, Rules, Shortcuts, Advanced.
`bordersrc`, `yabairc` and `sketchybarrc` are all generated by the app.

**Done:**

- **Phase 0 — safety rails.** JankyBorders fork under version control (pristine
  v1.9.0 verified against Homebrew's SHA-256 as commit 1, the local patch as
  commit 2). `doctor`. `SnapshotStore` with pruning.
- **Phase 1 — theme package.** Themes are `theme.json` manifests; `theme.env`
  is generated from them for the shell. Import/export/reset, colour editing,
  wallpaper picker, terminal preview from `ghostty.conf`.
- **Phase 2 — generated rc shims.** All three rc files authored by the app,
  each verified by restarting its daemon and diffing against baseline.
- **Phase 3b (started) — first surface ported.** Ghostty palette inlining,
  verified byte-identical across 16 comparisons.

---

## Phases remaining

### Phase 3b — port the rest of `theme-switch`

Follow the ghostty recipe exactly, easiest first: implement in `Desktop` →
extract the original shell verbatim as a `reference.sh` → diff across all 8
themes and the edge cases → only then delete the bash and point `theme-switch`
at `macarchy` → add a `doctor` assertion that it stays delegated.

| Surface | ~Lines | Lands in | Notes |
|---|--:|---|---|
| colour utils | 195 | `Desktop/System/` | hex, nearest-Apple-accent, highlight. Pure, testable, **start here** — everything else depends on it |
| core | 185 | `macarchy/ThemeCommand` | arg parsing, cycling, background selection. The entry point — port last |
| borders | 150 | `Desktop/Borders/` | largely done already in `BordersModel` |
| btop | 100 | `Desktop/Btop/` | writes a theme file and signals running instances |
| nvim | 90 | `Desktop/Neovim/` | big but a pure mapping table |
| sketchybar | 80 | `Desktop/Sketchybar/` | |
| shell env | 75 | `Desktop/Shell/` | writes `.shell-env` |
| macOS system | 35 | `Desktop/System/` | dark/light, accent, wallpaper |
| ~~Raycast~~ | 11 | — | dropped |
| ghostty | 15 | `Desktop/Ghostty/` | **done**, delegates already |

**Anything `theme-switch` writes to disk is a contract.** `.shell-env` is read
by zsh `precmd`/`preexec` hooks; `theme.env` is still sourced by `bordersrc`;
`FIREFOX_ACCENT` is read by `~/.local/bin/codex-ui.mjs`. The repo alone will
not tell you who reads a file — check the machine. A port reproduces every
output byte-identically.

**Gate per surface:** byte-identical output across all 8 themes, then `doctor`.

### Phase 3a — sketchybar items as packages

Independent of 3b, either order. Items become manifests like themes —
declarative properties plus, for some, a shell script.

**The trust boundary is the point.** A theme is pure data and can be imported
safely. An item that ships a script is importable *code* that runs every few
seconds. All four current items (battery, calendar, spaces, system_metrics) are
script-backed. So: items with no `script` import freely; items with a `script`
show it for review and require explicit confirmation, never running on import.
The UI always labels which kind an item is.

### Phase 4 — hotkeys

Parse `skhdrc` into structured bindings (86 of them, grouped by the section
comments already there) → editor UI with a key recorder → generate `skhdrc`.
skhd keeps doing global key capture; reimplementing that buys nothing.

**Gate:** generated `skhdrc` is semantically identical; all 86 fire.

### Phase 5 — consolidate state

`.current`, `.backgrounds.json`, `.nvim-colorscheme` and `.shell-env` still sit
*beside* the themes rather than inside them, because `theme-switch` owns them.
`float_state.json` → app state. This is also when `~/.config/themes` stops
needing to be a symlink.

### Phase 6 — retire

Delete in this order, each only once nothing references it:
`theme-switch` → the Raycast extension → `~/.config/macarchy` →
`~/.local/state/macarchy` → the `~/.config/themes` symlink.

---

## GUI conventions

`NavigationSplitView` with a source list sidebar — deliberately System
Settings-shaped, since that is the idiom being replaced.

- **`Form` with `.formStyle(.grouped)`** — native inspector look for free
- **Slider + numeric field side by side** — drag for feel, type for precision
- **No Save button.** Changes are live; Revert restores the last snapshot.
- **Inline validation.** If a daemon rejects a value, the row goes red with the
  daemon's own stderr as the message. Nothing is persisted on rejection.

Two pane-specific notes worth keeping:

- **Menu Bar:** there are 10 item definition files but ~28 live runtime items,
  because `spaces.sh` alone expands into `space.1`…`space.10`. Group by *source
  file*, not runtime item, or the pane shows ten near-identical rows.
- **Rules:** two sources must merge — `float_state.json` is a flat array of app
  names, while `yabai -m rule --list` returns richer objects. Union them keyed
  on app name and show which source each row came from.

---

## Traps

Every one of these actually happened.

**`theme-switch` regenerates files wholesale.** `write_borders_config()` rewrote
`bordersrc` on every theme switch and silently reverted a completed migration an
hour later, between checks. It is now a no-op and `doctor` asserts it stays
dead. Assume other functions do the same until you have read them.

**Do not split SketchyBar's chained invocation.** `--bar`, `--load-font` and
`--default` are one call on purpose — separate calls each cost a repaint. A
generator that extracted just the `--bar` group swallowed the font and every
item default with it; the bar still came up and sketchybar still reported
"running". Geometry is applied as a second small call instead.

**`set-wallpaper` is not to be ported.** It encodes desktoppr for the current
Space, direct `Index.plist` rewriting for the others, and osascript fallbacks.
Its failure mode is a grey desktop, which has bitten this machine before.

**`.backgrounds.json` overrides `theme.env`'s `WALLPAPER`.** They already
disagree for most themes. Reading `theme.env` alone shows the wrong image.

**Timestamps need sub-second resolution.** Snapshot ids were second-resolution;
writes debounce ~100ms apart, so captures collided in one directory and
`restore()` destroyed the snapshot it was reading from. Caught only by a test.

**`grep -c` prints `0` and exits `1`.** A `|| echo 0` fallback then emits two
lines and breaks numeric tests. Bit `doctor` in four places.

**zsh does not word-split unquoted parameter expansions.** `for k in $KEYS`
iterates once. It *does* split `$(command substitution)`, which makes the
difference easy to miss — `perl -pi -e ... $FILES` silently passes one giant
argument while `perl -pi -e ... $(find ...)` works.

**yabai tiles the app's own settings window.** It asks for 860×620 and gets
whatever yabai decides. Adding the app to its own float rules is a sensible
first customer for the Rules pane.

**`sudo yabai --load-sa`** is in a `macarchy:keep` region and relies on a
sudoers entry. The app must never invoke sudo. Restart daemons only via
`launchctl kickstart -k gui/$(id -u)/<label>`.

**More than one agent may be editing this repo.** A session's work was deleted
from the working tree mid-session, before anything was committed, and survived
only because it had been staged. Commit early; check `git status` before you
assume the tree is yours.

---

## Risks

| Risk | Mitigation |
|---|---|
| Wallpaper goes grey (has happened) | `set-wallpaper` not ported; `wallpaper-baseline` folded into `doctor` |
| A generated rc file loses a hand-written line | Preserved `macarchy:keep` regions; reboot gate in Phase 2 |
| Borders fork diverges from upstream | Under git; SHA-256 of the base recorded |
| Port drifts from bash behaviour | Diff harness per surface; byte-identical output required before deletion |
| App becomes required for a working desktop | Login stays launchd + rc shims; the GUI is never in the boot path |
| macOS 27 Space-switching breakage | App does not own Space switching; surfaced read-only in Advanced |
| `sudo yabai --load-sa` in `yabairc` | App never invokes sudo |

---

## Open questions

- **Scripted-item sandboxing.** Reviewing an imported script is a speed bump,
  not a security boundary — a reviewed script still runs unconfined every few
  seconds. Needs a decision before any shared library of items.
- **Colour ownership for SketchyBar.** Theme owns colour and settings owns
  geometry for borders. SketchyBar's bar colour is still a literal in the
  preserved region; it was left alone to keep the Phase 2 gate honest.
- **The macOS 27 Space-switching workaround** (`switch_space_macos27.sh`,
  `skhdrc:55`) is surfaced in the Advanced pane but still unresolved upstream.
- **The bar itself.** sketchybar stays a daemon. If the app ever drew the bar,
  that is a separate project, not part of this migration.
