# Architecture

Macarchy has three Swift targets: Macarchy (shared behaviour), App (SwiftUI), and
CLI (headless commands). The product is called Macarchy; the existing bundle
identifier and MacarchySettings executable remain stable for macOS identity.

## Ownership

`settings.json` owns the active theme, per-theme wallpaper choices, layout,
borders, menu bar preferences and floating-window rules. It has a schema version.
Atomic writes hold a cross-process lock around read-modify-write and snapshot the
previous version. Unchanged writes create no snapshots. Invalid JSON is an error.

The installed state directory remains `~/.config/macarchy-settings` during this
migration. Renaming it is independent of the product and source-tree rename.
`MACARCHY_HOME` redirects all managed paths for isolated tests.

Daemon queries provide observed state without overwriting saved preferences.
App startup reads only. `macarchy migrate` explicitly imports the old settings
and generates startup entry points; `macarchy apply` restores saved preferences.

## External programs

Integrations invoke separately installed programs through a process runner with
a timeout, cancellation and independent output capture. The wallpaper helper and
SketchyBar's existing item plugins remain external, including the Space-switching
workaround. Macarchy does not replace the daemons or update their binaries.

Theme file renderers are pure Swift and tested against the previous shell output
for all eight installed themes. Ghostty, btop and shell-colour files preserve the
existing output contract. Theme application shares border arguments with startup.

## Compatibility

`theme.env`, `.current`, `.nvim-colorscheme`, `.shell-env` and SketchyBar's
`theme.sh` remain generated compatibility outputs for external hooks. They are
not the app's settings source. The wallpaper helper and item scripts still have
real jobs; they are not silently removed as part of a directory cleanup.

Generated rc files preserve custom regions. Unexpected edits are snapshotted and
reported. Restore reads its source files before creating/pruning snapshots, and
replaces destination files atomically. `restore --apply` also updates the desktop;
a plain restore intentionally changes files only.

## Development checks

`swift test` exercises JSON persistence, serialised changes, process cancellation,
restore at the retention limit, shell-output parity and the app's Borders editor.
The integration test runs migration twice in a temporary home and checks that
preferences and custom regions survive, generated scripts parse, the second run
changes nothing, and invalid JSON is never replaced by legacy data:

```sh
python3 tests/integration/migration.py "$(swift build --show-bin-path)/macarchy"
```
