# Local square-border renderer

Square borders use a rectangular inner clipping path so that their colour does
not fill the rounded corner cut-outs of translucent windows. Native window
corners themselves are unchanged. Round mode keeps the upstream renderer.

Source: `/Users/harry/projects/jankyborders-local`, based on JankyBorders v1.9.0.
The cached upstream archive was verified against Homebrew's SHA-256:
`70b5bff531b67a082cc0108d88a8355ba5e7c8326285533143c185efdf21769f`.
The change is confined to the square-style clipping branch in `src/border.c`.

Build and check from that source directory:

```sh
make
python3 Tests/check_square_corners.py
codesign --force --sign - bin/borders
cp bin/borders ~/.local/bin/macarchy-borders
launchctl kickstart -k gui/$(id -u)/homebrew.mxcl.borders
```

`~/.config/borders/bordersrc` and `~/.local/bin/theme-switch` prefer the local
binary when present, falling back to Homebrew. The app's existing Homebrew CLI
still sends compatible commands to this daemon. Only one daemon runs.
Homebrew's installed binary is unchanged. Replacing theme-switch or bordersrc
with an older version can remove the local binary selection.

For rollback, restore bordersrc and theme-switch from
`~/.local/state/macarchy/square-border-fix/*.before`, then restart the service.
Those backups include the earlier visibility fix.

Validation: release renderer build, code-signature verification, shell syntax
checks, and raster assertions using the actual border_draw function at full and
half opacity, both above and below windows. The local daemon was confirmed
running with square style and width 6.0.

## Mission Control tracking and focus

The local renderer also samples public on-screen window bounds on the display
refresh cycle, applying a transform to the existing border surface. This scales
border thickness with the window and avoids repeated shape redraws. At most one
main-queue refresh can be pending. Yabai animation proxies retain their existing
tracking path.

Focus is reconciled on leaving the transformed view and every 100 ms to recover
from missing Dock/window notifications. A 350 ms grace period preserves the
previous highlight while Dock temporarily reports no focused window; genuinely
empty desktops then clear it. This never changes application keyboard focus.

Additional checks: `Tests/check_focus_recovery.py` and
`Tests/check_presentation_transform.c`. The latter is compiled with
`clang -std=c99 -Isrc Tests/check_presentation_transform.c -framework CoreGraphics`.

Space swipes are excluded from custom presentation tracking: only a size change
beyond half a point activates scaling. Pure translation is left to WindowServer's
Space animation. Presentation transforms are cleared for windows leaving the
on-screen list. Focus reconciliation also restores an ordered-out active border,
even when its internal focused flag was already true; overview exit refreshes
borders on visible Spaces.
