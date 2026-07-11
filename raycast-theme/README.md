# Raycast theme switcher

This extension shows your installed themes in Raycast and passes the selected name to `theme-switch`. The shell command remains responsible for applying the theme.

By default, it looks for:

- the command at `~/.local/bin/theme-switch`
- themes in `~/.config/themes`
- theme state in `~/.local/state/macarchy/themes`

All three paths can be changed in the extension preferences. `~` and `$HOME` are expanded before the paths are used, and the theme and state directories are passed to `theme-switch` when a selection is applied. If Macarchy was installed with a custom `XDG_STATE_HOME`, set Theme State Directory to `$XDG_STATE_HOME/macarchy/themes` using its full path.

## Install it

Install the theme switcher and at least one theme first:

```sh
./install themes raycast
cd "${XDG_DATA_HOME:-$HOME/.local/share}/macarchy/raycast-theme"
fnm use --install-if-missing
npm ci
npm run dev
```

The installer keeps this development source under the XDG data directory. Raycast writes the compiled command to `~/.config/raycast/extensions/theme-switcher`. That second directory is generated runtime output. Do not run `npm install` or edit source there, because a local React copy beside the command prevents Raycast from loading it correctly.

When working from a repository clone instead, run the same Node and npm commands from `raycast-theme/` in the clone.

The included `.nvmrc` selects Node.js 24 when you use fnm or another compatible version manager. If you do not use one, make sure `node --version` satisfies the version in `package.json` before installing dependencies.

Raycast will open the extension in development mode. Use `npm run lint` and `npm run build` before publishing changes.
The build command writes its output to the ignored `dist/` directory and does not replace your active Raycast command.

## Publishing

The manifest uses `macarchy` as a neutral project author. Raycast only accepts an existing Store handle when publishing, so a maintainer must replace this value with their own Raycast handle first. Until then, `npm run validate:store` reports the author during manifest validation; local linting and builds still work normally.
