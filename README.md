# Macarchy

A native macOS app and command for configuring a personal desktop: yabai,
JankyBorders, SketchyBar, skhd and application themes.

The app and command share the same Swift implementation. Preferences live in
JSON. External desktop programs remain separately installed dependencies.

## Development

Requires the Xcode 27 toolchain and the existing desktop dependencies.

```sh
swift build
swift test
./tools/lint.sh
./tools/build.sh debug
```

Building produces `.build/artifacts/Macarchy.app` and `.build/artifacts/macarchy`. It does not install,
restart services or change desktop configuration.

## Layout

- `macarchy/app`: SwiftUI pages, previews and controls.
- `macarchy/core`: shared configuration, themes and external-program integrations.
- `macarchy/commands`: command entry points.
- `macarchy/resources/themes`: shipped theme defaults.
- `tools/compat`: maintained startup entry points, not copies of personal configuration.
- `macarchy/tests`: behavioural tests and reference fixtures.
- `tools`: build, install and lint automation.
- `docs`: architecture and migration details.

Read [CONTRIBUTING.md](CONTRIBUTING.md) before changing the code, and
[docs/architecture.md](docs/architecture.md) before changing desktop ownership.
Installation is described in [docs/migration.md](docs/migration.md).

## Live design iteration

Run `./tools/run.sh debug` to build and open the development app. Debug builds
watch `design/appearance.json` once a second. Changing the page width, sidebar
width, card corners, catalogue spacing, Workshop copy or sample listings updates
the running interface without a restart. Invalid edits keep the last valid
appearance and show a small error message. Release builds use built-in defaults.

Changes to Swift view structure still need a rebuild. The app remembers the
selected page and whether the sidebar is visible. Workshop and Plugins currently
show concept catalogues; they do not download, buy, install or remove anything.
