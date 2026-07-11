# SketchyBar

The `sketchybar` component installs the bar config, the app icon font and its small shell plugins.

```sh
./install sketchybar
brew services start sketchybar
```

For application labels inside each Space, install the `window-manager` component as well. Without yabai, the rest of the bar still loads and the Space list falls back gracefully.

## System metrics

On Apple Silicon, the installer adds [macmon](https://github.com/vladkens/macmon). A small local worker runs `macmon pipe` and writes the newest sample under the SketchyBar state directory. It does not start macmon's HTTP server or open port 9090.

One hidden SketchyBar item reads that sample every five seconds and updates CPU, GPU and RAM together. Network speed has its own five-second updater because it compares macOS interface counters over time.

If macmon is unavailable, the sensor values show placeholders. The bar remains usable on Intel Macs, where macmon is not supported.

## Themes

`colors.sh` has safe defaults and reads the generated `theme.sh` file when the `themes` component is installed. Applying a theme reloads SketchyBar automatically.

## Debugging

Stop the service and run the bar in the foreground to see plugin errors:

```sh
brew services stop sketchybar
sketchybar
```

After fixing the issue, press Control-C and restart the service. `sketchybar --reload` is enough for ordinary config changes.
