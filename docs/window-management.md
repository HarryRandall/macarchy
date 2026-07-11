# Window management

The `window-manager` component installs configs for [yabai](https://github.com/asmvik/yabai), [skhd](https://github.com/asmvik/skhd) and [JankyBorders](https://github.com/FelixKratz/JankyBorders).

```sh
./install window-manager
```

Review the files, grant Accessibility access to yabai and skhd, then start the services you want:

```sh
yabai --start-service
skhd --start-service
brew services start borders
```

## Default shortcuts

The default skhd file contains window-management bindings only. Application launchers, media keys and theme controls are examples you can opt into separately.

| Shortcut | Action |
| --- | --- |
| `⌃⌥F` | Toggle fullscreen for the focused window |
| `⌃⌥` + arrow | Focus a window in that direction |
| `⌃⌥⇧` + arrow | Swap with a window in that direction |
| `⌃⌥1` to `⌃⌥0` | Focus Spaces 1 to 10 |
| `⌃⌥⇧1` to `⌃⌥⇧0` | Move a window to a Space and follow it |
| `⌃⌥T` | Toggle floating and remember the choice for that app |
| `⌃⌥J` | Toggle the BSP split direction |
| `⌃⌥L` | Rotate and rebalance the current layout |
| `⌃⌥=` and `⌃⌥-` | Change the focused split ratio |

Optional application launchers, theme controls, screenshots and scripting-addition Space swaps live in [`skhd/examples`](../skhd/examples). They are not loaded by default.

The installed `skhdrc` loads `~/.config/skhd/local.skhdrc`, or the equivalent XDG path. The installer creates that file once and never manages or removes it, so it is the right place for personal app shortcuts and legacy key combinations. Copy examples there rather than editing the managed `skhdrc`.

Floating preferences are stored as a JSON array in `~/.config/yabai/float_state.json`, or the equivalent XDG path. The generated yabai rules are labelled, so reloading the config replaces them instead of adding duplicates.

An additional helper under [`yabai/examples`](../yabai/examples) can bring a minimised window onto the current Space when its app is activated. It is not enabled by default because moving a window automatically can be surprising. Wire it to an `application_activated` signal only if that is the behaviour you want.

The same examples directory contains a workaround that restarts JankyBorders after a native fullscreen Space closes. It is also opt-in because it restarts a user service. Add the labelled yabai signals yourself only if you encounter stale border overlays.

## Optional scripting addition

Most everyday tiling works with SIP enabled. Some Space operations, including swapping Spaces, need yabai's scripting addition and a partially disabled SIP configuration.

Changing SIP is a meaningful reduction in macOS security and is never automated by Macarchy. Read yabai's current [SIP instructions](https://github.com/asmvik/yabai/wiki/Disabling-System-Integrity-Protection) before deciding whether those features are worth it.

If you enable the scripting addition, follow yabai's [installation guide](https://github.com/asmvik/yabai/wiki/Installing-yabai-(latest-release)) to create a hash-pinned sudoers rule for `yabai --load-sa`. Macarchy checks that rule with non-interactive sudo. When it is available, the config loads the addition and reloads it after Dock restarts; otherwise it quietly skips it.

The binary hash changes after a yabai upgrade, so update the sudoers entry each time. Do not replace the hash-pinned rule with unrestricted passwordless sudo.

## Personal changes

Padding, gaps, mouse behaviour and the small set of floating system windows are grouped near the bottom of `yabairc`. Keep machine-specific rules in your installed copy and review the backup shown by the installer before updating that component.
