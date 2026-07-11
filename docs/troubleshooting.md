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

Intel Macs intentionally use placeholders for CPU, GPU and RAM sensors. Network and battery items do not need macmon.

## A theme only partly applies

Run it from a terminal to see the failing target:

```sh
theme-switch carbonfox
```

The active theme is only recorded after all required writes succeed. Optional applications that are not installed are skipped.

## Raycast store validation rejects the author

Local linting and builds work with the neutral `macarchy` author. Raycast Store publishing requires a real Raycast handle, so a publisher must change the manifest author before running:

```sh
cd raycast-theme
npm run validate:store
```
