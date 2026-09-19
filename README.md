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
./scripts/lint.sh
./scripts/build_app.sh debug
```

Building produces `dist/Macarchy.app` and `dist/macarchy`. It does not install,
restart services or change desktop configuration.

## Layout

- `src/app`: SwiftUI pages, previews and controls.
- `src/macarchy`: shared configuration, themes and external-program integrations.
- `src/cli`: command entry points.
- `themes`: shipped theme defaults.
- `dotfiles`: maintained startup entry points, not copies of personal configuration.
- `tests`: behavioural tests and reference fixtures.
- `scripts`: build, install and lint automation.
- `docs`: architecture and migration details.

Read [CONTRIBUTING.md](CONTRIBUTING.md) before changing the code, and
[docs/architecture.md](docs/architecture.md) before changing desktop ownership.
Installation is described in [docs/migration.md](docs/migration.md).
