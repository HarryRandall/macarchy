# Troubleshooting

## See what would change

```sh
./install --dry-run terminal
./install status terminal
```

`status` reports missing or modified managed files and exits non-zero when something needs attention.

## Homebrew refuses a third-party tap

Recent Homebrew versions can require explicit trust before loading formulae from a non-official tap. Review the upstream repository first, then trust only the formula you need:

```sh
brew trust --formula asmvik/formulae/yabai
brew trust --formula FelixKratz/formulae/sketchybar
```

Rerun the installer after approving it.

## A service cannot find its config

If you use a non-default `XDG_CONFIG_HOME`, expose it to the launchd user session before starting services:

```sh
launchctl setenv XDG_CONFIG_HOME "$XDG_CONFIG_HOME"
```

Then restart the affected service.

## yabai Space commands fail

Confirm Accessibility access first. Space swapping and some other advanced operations also require yabai's optional scripting addition. The [window management guide](./window-management.md) explains the boundary and links to the current upstream instructions.

## SketchyBar shows metric placeholders

Apple Silicon metrics require `macmon` and the local sampler started by SketchyBar. Check both processes and reload the bar:

```sh
command -v macmon
pgrep -fl 'macmon pipe'
sketchybar --reload
```

Intel Macs intentionally omit the CPU, GPU and RAM tiles. Network and battery items do not need macmon.

Older Macarchy releases used `macmon serve` on port 9090. The current config uses a local pipe and does not stop an old process automatically. After upgrading, check before ending it:

```sh
pgrep -fl 'macmon serve'
```

If that output is the old Macarchy process, stop its listed PID normally and reload SketchyBar. Do not kill an unrelated macmon session.

## A theme only partly applies

Run it from a terminal to see the failing target:

```sh
"$HOME/.local/bin/theme-switch" carbonfox
```

The active theme is only recorded after all required writes succeed. Optional applications that are not installed are skipped.

## Ghostty still uses old settings

Ghostty loads its macOS Application Support config after its XDG config. Check both locations if a setting still overrides Macarchy:

```sh
sed -n '1,120p' "$HOME/.config/ghostty/config.ghostty"
sed -n '1,120p' "$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"
```

The installer neutralises the older XDG file named `config`, but it only warns about a non-empty Application Support file because that file may be intentionally machine-specific.

## Raycast store validation rejects the author

Local linting and builds work with the neutral `macarchy` author. Raycast Store publishing requires a real Raycast handle, so a publisher must change the manifest author before running:

```sh
cd raycast-theme
npm run validate:store
```
