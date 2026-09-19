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
