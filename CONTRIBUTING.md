# Contributing

Macarchy configures a daily-use desktop. Keep development builds separate from
installation, preserve unrelated work, and commit focused, reviewable changes.

## Checks

Run `swift build`, `swift test`, `./tools/lint.sh` and
`macarchy/tests/integration/setup.sh`. CI runs the same. Tests must use temporary
homes (`MACARCHY_HOME`), fake tools (`MACARCHY_SEARCH_PATH`) and must never alter
the running desktop. Tool versions: Xcode 27's `swift-format`, and the SwiftLint
release pinned in `.github/workflows/ci.yml`.

## Structure and naming

Directories use lowercase names with hyphens between words. Swift filenames
match their primary type. Keep conventional filenames such as `Package.swift`
and `Info.plist`. Do not add empty folders for speculative future features.

The App and CLI targets use the shared Macarchy target. UI state belongs in
`macarchy/app`; themes, configuration and integration behaviour belong in
`macarchy/core`. Add targets or protocols only when a concrete dependency or test
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
- Everything Macarchy owns lives in `~/.config/macarchy`, through `Paths`.
  Write outside it only where a tool requires a fixed location, and only after
  `Setup` has backed the file up.
- Every integration is optional. Detect it, skip it when it is missing, and say
  so; never fail a whole operation because one tool is absent.
- Locate executables with `Paths.executable`, never a hard-coded prefix.
- Ship desktop files in `macarchy/resources`; they are bundled into the app.
- Nothing here may require System Integrity Protection to be disabled.

## Style

Use British English, straight apostrophes and no em dashes in new prose.
Comments explain constraints and decisions; avoid repeating code or recording
volatile line counts. Use Swift 6 concurrency checks and the repository formatter.

Commit messages use `feat:`, `fix:`, `refactor:` or `docs:`.

## Errors and logging

Throw `ConfigurationError` with a sentence a person can act on. Use `try?` only
where absence is an expected, documented outcome. In the app, record command
results with `CommandLog.record`, notes with `note` and failures with `failure`.
Report partial application explicitly rather than as success.

## Interface help

Prefer contextual tooltips for secondary instructions over persistent explanatory
lines. Use `HelpTooltip` for help beside a group and `hoverHelp` for an individual
control. Keep wording brief and describe the action. Keep essential status, errors
and information needed to make a decision visible. Use the shared tooltip host so
wrapped text stays inside its bubble and above scrolling content.
