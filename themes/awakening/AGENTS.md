# Repository Guidelines

## Project Structure & Module Organization

This repository is an Omarchy theme pack made of theme-local config files rather than application source code.

- `colors.toml` is the canonical palette and semantic color source.
- Shell and desktop surfaces live at the repo root: `walker.css`, `hyprlock.conf`, `hyprland.conf`, `mako.ini`, `swayosd.css`, `gtk.css`, `aether.override.css`.
- `waybar.css` is optional in this repository when Omarchy provides or generates the active Waybar theme surface externally.
- Terminal and editor integrations also live at the root: `foot.ini`, `kitty.conf`, `ghostty.conf`, `alacritty.toml`, `neovim.lua`, `warp.yaml`, `aether.zed.json`.
- Visual assets are stored in `backgrounds/`.
- Design rationale belongs in `DESIGN.md`.

Keep changes theme-local. Do not assume code outside this directory will be edited alongside theme work.

## Build, Test, and Development Commands

There is no build system or automated test suite in this repository.

- `rg --files` lists the theme surface files quickly.
- `sed -n '1,120p' colors.toml` inspects the canonical palette.
- `rg -n "#[0-9A-Fa-f]{6}" .` audits hard-coded colors for palette drift.

Validation is visual and manual: apply the theme in Omarchy, then verify Waybar, Walker, Hyprlock, GTK apps, notifications, and terminal colors. Do not assume Waybar validation requires a checked-in `waybar.css` in this repo.

## Coding Style & Naming Conventions

Use the existing file formats and keep edits minimal.

- CSS: 4-space indentation, lowercase hex colors, concise selectors.
- TOML/INI/CONF: preserve current key ordering and spacing style.
- New assets should use descriptive lowercase filenames with underscores, for example `neon_city_rain.jpg`.

Prefer updating `colors.toml` first, then propagate palette changes consistently to dependent files.

## Testing Guidelines

There are no framework-based tests or coverage targets.

For each change:

1. Check for semantic consistency across `colors.toml`, CSS, and terminal configs.
2. Confirm text contrast on dark backgrounds.
3. Smoke-test at least one wallpaper, Waybar, Walker, Hyprlock, and one terminal.

## Commit & Pull Request Guidelines

Git history is not available in this directory, so no local commit convention can be inferred. Use short imperative commit messages such as `Refine active border semantics` or `Sync Waybar with palette`.

Pull requests should include:

- a brief summary of the visual intent
- screenshots for affected surfaces
- notes on any wallpaper or semantic color changes
- confirmation of manual smoke testing
