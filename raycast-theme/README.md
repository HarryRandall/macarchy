# Raycast theme switcher

This extension shows your installed themes in Raycast and passes the selected name to `theme-switch`. The shell command remains responsible for applying the theme.

By default, it looks for:

- the command at `~/.local/bin/theme-switch`
- themes in `~/.config/themes`

Both paths can be changed in the extension preferences. `~` and `$HOME` are expanded before the paths are used.

## Run it locally

Install the theme switcher and at least one theme first. Then run:

```sh
npm install
npm run dev
```

Raycast will open the extension in development mode. Use `npm run lint` and `npm run build` before publishing changes.

## Publishing

The manifest uses `macarchy` as a neutral project author. Raycast only accepts an existing Store handle when publishing, so a maintainer must replace this value with their own Raycast handle first. Until then, `npm run validate:store` reports the author during manifest validation; local linting and builds still work normally.
