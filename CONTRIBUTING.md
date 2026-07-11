# Contributing

Thanks for helping improve Macarchy.

Keep changes focused on portable macOS configuration. Personal app rules, account switchers and machine-specific paths should be examples or local overrides rather than defaults.

Before opening a pull request:

```sh
./scripts/check.sh
```

The check covers shell syntax, installer behaviour, theme safety, personal-path scanning and the Raycast build. Do not run a real install or apply a theme as part of a test.

For a new component, include a dry-run path, a safe uninstall path and a short guide. For a new theme, include its source, licence and wallpaper credits in `THIRD_PARTY_NOTICES.md`.

Use clear commit prefixes such as `feat:`, `fix:`, `refactor:` and `docs:`. Write in plain language and explain behaviour that is not obvious from the code.
