import type { Background, ThemeDetail } from "~/bridge/protocol";
import { formatColour, parseColour } from "~/lib/colour";

/** What the pages draw for a theme, read from its saved values and terminal palette. */
export interface ThemeLook {
  name: string;
  title: string;
  dark: boolean;
  /** `#rrggbb`: the active border colour, which Macarchy treats as the theme's accent. */
  accent: string;
  background: string;
  foreground: string;
  /** Terminal colours 0 to 7. */
  palette: string[];
  /** The Neovim colourscheme in force: the theme's choice or its default. */
  nvim: string;
  wallpapers: readonly Background[];
  /** The wallpaper in force for this theme, if it has any. */
  wallpaper: Background | null;
  modified: boolean;
}

const fallbackBackground = "#141414";
const fallbackForeground = "#e4e4e7";

/** The palette from the theme's Ghostty colours, or a stand-in from its summary colours. */
function paletteOf(theme: ThemeDetail, background: string, foreground: string): string[] {
  const ansi = theme.terminal?.ansi ?? [];
  if (ansi.length >= 8) return ansi.slice(0, 8);
  const colours = theme.summary.colours;
  const ring = theme.summary.ring;
  if (!colours) return [background, ring, ring, ring, ring, ring, ring, foreground];
  const { red, green, blue, cyan } = colours;
  return [background, red, green, ring, blue, ring, cyan, foreground];
}

export function themeLook(theme: ThemeDetail): ThemeLook {
  const { summary, values } = theme;
  const border = parseColour(values.borderActive);
  const background =
    theme.terminal?.background ?? summary.colours?.background ?? fallbackBackground;
  const foreground =
    theme.terminal?.foreground ?? summary.colours?.foreground ?? fallbackForeground;
  return {
    name: summary.name,
    title: summary.title,
    dark: values.dark,
    accent: border ? formatColour(border, "rgb") : summary.ring,
    background,
    foreground,
    palette: paletteOf(theme, background, foreground),
    nvim: values.nvimColorscheme ?? theme.defaultColourscheme,
    wallpapers: summary.backgrounds,
    wallpaper:
      summary.backgrounds.find((item) => item.path === summary.currentBackground) ??
      summary.backgrounds[0] ??
      null,
    modified: theme.modified,
  };
}

/** The image for a wallpaper tile, or the theme's large preview when none is chosen. */
export function wallpaperImage(
  look: ThemeLook,
  wallpaper: Background | null,
  preview: string | null,
) {
  if (!wallpaper) return preview;
  if (wallpaper.path !== look.wallpaper?.path) return wallpaper.thumbnail;
  return preview ?? wallpaper.thumbnail;
}

/** "Hand Of Adam" as the host names it; bare numbers read as "Wallpaper 2". */
export function wallpaperName(look: ThemeLook, wallpaper: Background): string {
  const name = wallpaper.name.trim();
  if (name && !/^(?:bg|wall(?:paper)?)?\s*\d*$/i.test(name)) return name;
  return `Wallpaper ${look.wallpapers.findIndex((entry) => entry.path === wallpaper.path) + 1}`;
}

/** The wallpaper after the one in force, wrapping round; null when there is nothing to change to. */
export function nextWallpaper(look: ThemeLook): Background | null {
  if (look.wallpapers.length < 2) return null;
  const index = look.wallpapers.findIndex((entry) => entry.path === look.wallpaper?.path);
  return look.wallpapers[(index + 1) % look.wallpapers.length] ?? null;
}

/** The wallpaper's place as "2/4", or null when the theme has none. */
export function wallpaperPosition(look: ThemeLook): string | null {
  if (!look.wallpaper) return null;
  const index = look.wallpapers.findIndex((entry) => entry.path === look.wallpaper?.path);
  return `${index + 1}/${look.wallpapers.length}`;
}

/** The theme `by` places along, wrapping round, for the detail view's previous and next. */
export function stepTheme<T>(themes: readonly T[], index: number, by: number): T | undefined {
  if (!themes.length) return undefined;
  return themes[(((index + by) % themes.length) + themes.length) % themes.length];
}
