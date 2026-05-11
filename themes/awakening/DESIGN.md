# Awakening Design Notes

`Awakening` is a high-energy cyberpunk theme built around contrast, rebellion, and active-state intensity.

It is not aiming for a quiet, single-world cinematic shell. It is aiming for a loud visual collage that still feels authored. The wallpapers, ANSI palette, and shell surfaces all lean into that premise: hard dark neutrals, electric cool tones, and hot active highlights.

## Direction

The theme lives in a graphic neon lane:

- dark, almost burnt-black foundations
- cool electric blue as the stable interactive anchor
- hot yellow and orange as the active and energized edge
- purple as the synthetic neon support color
- pale lavender text instead of pure white, to keep the interface vivid without becoming sterile

The intended mood is not minimalism. It is pressure, motion, glare, nightlife, and confrontation.

## Wallpaper Philosophy

The wallpaper set is intentionally eclectic.

The unifying idea is not one literal environment. The throughline is attitude:

- cyberpunk
- punk poster energy
- anime and comic-book intensity
- neon spectacle
- defiant, high-contrast imagery

This theme should be read as a mixtape, not a single film still stretched across multiple images.

Because of that, the UI should provide structure rather than compete for novelty. The shell needs to frame the artwork with a clear semantic hierarchy.

## Palette Roles

Canonical palette source: [colors.toml](/home/oldjobobo/Projects/themes/omarchy-awakening-theme/colors.toml)

### Core Neutrals

- `background = #141010`
  Deep burnt black. The visual floor of the theme.
- `foreground = #dacbe6`
  Soft lavender-white. Bright enough to read clearly, softer than pure white.
- `cursor = #fffbd4`
  Warm bright ivory for immediate visibility.

### Primary UI Semantics

- `accent = #1d52a1`
  Primary focus and interaction color.
- `active_border_color = #ffff00`
  Active-state signal. This is the loud edge, not a generic accent.
- `selection_background = #1d52a1`
  Selection uses the primary accent, not the active border color.

This split matters:

- blue means focus, interaction, and selection
- yellow means active, live, or currently energized

That is the theme's core semantic contract.

## Accent Model

`Awakening` uses a dual-accent structure.

- Blue is the stable control color.
- Yellow and orange are the charge layer.

That gives the theme motion without sacrificing legibility. The shell can feel aggressive while still making state meaning readable.

Purple supports this system as a synthetic neon edge color. It should help transitions, gradients, and decorative framing, but it should not replace blue as the main interaction signal.

## ANSI Intent

The ANSI palette is part of the theme identity, not just a terminal afterthought.

- `color4` / blue and `accent` carry the main shell focus
- `color2` / yellow and `color9` / orange carry activity and heat
- `color5` / purple gives the theme its synthetic neon atmosphere
- `color3` / magenta-red is for danger, urgency, or punk aggression
- `color6` / cyan is a supporting cool utility color

The ANSI set is intentionally saturated. The restraint should come from how those colors are assigned, not from muting the palette itself.

## Surface Strategy

The surface language is sharp and graphic with controlled translucency.

- dark translucent panels
- crisp borders instead of soft rounded containers
- selective glow through color contrast rather than blur everywhere
- gradients used as energy bands, not decorative filler

The shell should feel like black glass and painted metal under neon light.

## Component Guidance

### Waybar

Waybar should read as the control strip.

- dark modules
- bright top-edge emphasis
- active workspaces get the most heat
- support modules can use secondary hues, but the hierarchy should stay obvious

If Waybar gets noisy, reduce accent assignment before reducing saturation.

### Walker

Walker is where the theme can be most theatrical.

- strong selection treatment
- obvious focus state
- dramatic gradients are acceptable
- text must stay fast to parse

It should feel like stepping into the theme's energized center, not like a neutral utility dialog.

### GTK and App Surfaces

GTK should stay simpler than the launcher and wallpapers.

Applications need enough calm structure to keep the whole theme usable. The palette can remain vivid, but app chrome should not fight the wallpaper set for attention.

## Design Rules

When extending or revising the theme, keep these rules:

1. Preserve the semantic split between `accent` and `active_border_color`.
2. Use yellow for active/live emphasis, not as a generic substitute for every highlight.
3. Keep blue as the default interactive color.
4. Let purple support the mood and edge treatment without becoming the main signal.
5. Use the wallpaper set's attitude as the source of identity, and let the UI provide the structure around it.
6. Prefer bold contrast over muted compromise.
7. If something feels chaotic, fix the hierarchy first, not the saturation.

## Short Version

`Awakening` is a dark cyberpunk collage theme with:

- burnt-black foundations
- electric blue focus
- radioactive yellow active states
- orange heat
- purple neon support
- eclectic, confrontational wallpapers

The theme works when the shell behaves like a control frame around that energy.
