# SpaceGesture

Instant Space switching: a synthetic Dock swipe so fast there is no slide.

Trimmed from [InstantSpaceSwitcher](https://github.com/jurplel/InstantSpaceSwitcher)
at commit `76fd272761d81563f8f747cf7d7ff266ec7ec4e3` (4 November 2026).

| Here | Upstream |
|---|---|
| `SpaceGesture.c` | The swipe posting, natural scrolling sign and Mission Control and Exposé detection in `Sources/ISS/ISS.c` |
| `DockSwipePayload.c` | `Sources/ISS/event_serialize.c`, the macOS 27 IOHID payload |
| `SwipeOverride.c` | The event tap and swipe override in `ISS.c` (`eventTapCallback`), with its decisions split into `sg_swipe_decide` |
| `internal.h` | The event field numbers at the top of `ISS.c` |

Left out: predictions, Space info,
window carrying (`window_drag.c`, `bridged_ops.c`, `window_focus.c`),
hotkeys, the app and `ISSCli`. Macarchy reads Spaces in Swift
(`SpacesReading`) and keeps where a burst is heading itself.

Changed: a swipe begun in Mission Control, not only App Exposé, goes to the
Dock untouched, and a cancelled swipe that was never caught passes. The
payload is written into a caller's buffer instead of a
`malloc`, so tests can read it; the swipe event can be built without posting
it; the natural scrolling preference is cached atomically and refreshed
by its change notification without an init call.

To compare with a later upstream, diff the functions named in the table.
The CGEvent field numbers and the payload layout are undocumented; if a macOS
update stops switches landing, start there.

## Licence

```
MIT License

Copyright (c) 2026 jurplel

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
