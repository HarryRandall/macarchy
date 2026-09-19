# Contributing

Macarchy configures a daily-use desktop. Keep development builds separate from
installation, preserve unrelated work, and commit focused, reviewable changes.

## Checks

Run `swift build`, `swift test` and `./scripts/lint.sh`. After an installed
configuration change, run `macarchy doctor`. Unit tests must use temporary
configuration directories and must not alter the running desktop.

## Structure and naming

Directories use lowercase names with hyphens between words. Swift filenames
match their primary type. Keep conventional filenames such as `Package.swift`
and `Info.plist`. Do not add empty folders for speculative future features.

The App and CLI targets use the shared Macarchy target. UI state belongs in
`src/app`; themes, configuration and integration behaviour belong in
`src/macarchy`. Add targets or protocols only when a concrete dependency or test
needs them. Prefer small concrete types over generic frameworks.

## Behaviour

- Opening and refreshing the app are read-only. Migration is explicit.
- JSON owns saved preferences; daemon queries report observed state.
- Apply before committing preferences. Report partial application and failed
  persistence clearly. Never silently treat invalid configuration as empty.
- One implementation serves the app, command and startup paths.
- Call executables with argument arrays through the shared process runner.
- Generate required native formats; do not maintain a second editable settings
  source in shell files.
- Snapshot before destructive writes. Preserve custom startup regions and
  report externally edited generated files.
- Keep wallpaper handling in the existing `set-wallpaper` helper. Preserve the
  temporary macOS Space-switching workaround until separately verified.
- Before removing a compatibility output, inspect its readers on the machine.
  Shell hooks and external tools are not all discoverable in this repository.
- Validate shell ports against reference output before changing the installed
  entry point. Keep reference scripts in tests, not production code.

## Style

Use British English, straight apostrophes and no em dashes in new prose.
Comments explain constraints and decisions; avoid repeating code or recording
volatile line counts. Use Swift 6 concurrency checks and the repository formatter.

Commit messages use `feat:`, `fix:` or `refactor:`. Do not add agent co-author
trailers. Preserve the existing app identity and executable during the visible
rename so macOS permissions and launch references remain stable.
