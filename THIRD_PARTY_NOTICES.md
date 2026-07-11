# Third-party notices

Macarchy's root MIT licence covers the original installer, scripts and configuration adapters. It does not replace the licences of the third-party material listed here.

No third-party wallpaper source files are included in the current tree. [`media/macarchy-preview.gif`](./media/macarchy-preview.gif) is a screen recording of the original local setup and shows wallpaper packs that are not bundled with Macarchy. It is included to demonstrate the interface; Macarchy does not grant reuse rights for artwork visible in the recording.

Earlier versions contained wallpaper source files with incomplete or restrictive provenance. Their blobs still exist in Git history, so a clean new snapshot or a separately approved history rewrite is required before describing the repository history as sanitised.

## LazyVim starter

Parts of the Neovim configuration are derived from the [LazyVim starter at commit `803bc181d7c0d6d5eeba9274d9be49b287294d99`](https://github.com/LazyVim/starter/tree/803bc181d7c0d6d5eeba9274d9be49b287294d99).

The bootstrap files remain close to the upstream starter, while Macarchy adds its own theme state, transparent-background handling and dashboard behaviour. LazyVim starter is licensed under the Apache License 2.0. A copy is included at [`LICENSES/Apache-2.0.txt`](./LICENSES/Apache-2.0.txt).

## Theme palettes

### Blackgold

Adapted from [HANCORE's Blackgold theme](https://github.com/HANCORE-linux/omarchy-blackgold-theme/tree/48361b9593fd3e51769a8350025fb454f0de141b).

Copyright (c) 2025 HANCORE. Licensed under the MIT licence below.

### Carbonfox

Adapted from [Carbonfox](https://github.com/gchmel/carbonfox/tree/c2200fff57b6d6f005d1152feb8067ee4b1da97e) and the [Nightfox Neovim theme](https://github.com/EdenEast/nightfox.nvim/tree/4dacd3f0185a2227bdf3b6c0975a8f0bf87cac9a).

Copyright (c) 2026 Georgy Chmel.

Copyright (c) 2021 James Simpson.

Both sources are licensed under the MIT licence below.

### Cool Blue and Matte Black

Adapted from the Lumon and Matte Black palettes in [Basecamp's Omarchy](https://github.com/basecamp/omarchy/tree/9cf1852525a5f7de26d3162db9d61e2f5c1d5523/themes).

Copyright (c) David Heinemeier Hansson. Licensed under the MIT licence below.

Cool Blue is a renamed colour adapter. Macarchy is not affiliated with Apple or the Severance television series.

### Amber Metal

Adapted from [HANCORE's Turbonite theme](https://github.com/HANCORE-linux/omarchy-turbonite-theme/tree/921aea335619bbfff187403dadca2bd75ee364f8).

Copyright (c) 2026 HANCORE. Licensed under the MIT licence below.

Amber Metal is a renamed colour adapter. Macarchy is not affiliated with Porsche or Porsche Design.

### MIT licence text for the palette sources

MIT License

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

## SketchyBar application mappings

[`sketchybar/plugins/icon_map.sh`](./sketchybar/plugins/icon_map.sh) is generated from or derived from [sketchybar-app-font at commit `11b080e4211038114746c8423abac7557e0b7a86`](https://github.com/kvndrsslr/sketchybar-app-font/tree/11b080e4211038114746c8423abac7557e0b7a86), which is released under [CC0 1.0 Universal](https://github.com/kvndrsslr/sketchybar-app-font/blob/11b080e4211038114746c8423abac7557e0b7a86/LICENSE).

The font itself is installed separately through Homebrew and is not copied into this repository.
