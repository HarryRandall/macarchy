import type { ThemeDetail } from "~/bridge/protocol";

import {
  barDesigns,
  type CommunityTheme,
  communityThemes,
  featured,
  type Kind,
  layoutDesigns,
  neutralColours,
  type WorkshopItem,
} from "./workshop-mock";

export const kindLabels: Record<Kind, string> = {
  theme: "Theme",
  wallpaper: "Wallpaper",
  layout: "Layout",
  bar: "Bar",
};

/** FNV-1a, so a design's made-up download count stays the same between visits. */
export function hash(text: string): number {
  let value = 2166136261;
  for (let index = 0; index < text.length; index++) {
    value = Math.imul(value ^ text.charCodeAt(index), 16777619);
  }
  return Math.abs(value);
}

export function seededDownloads(id: string, base: number, spread: number): number {
  return base + (hash(id) % spread);
}

/** 950, 1.2k, 38k. */
export function formatCount(count: number): string {
  if (count >= 1000) return `${(count / 1000).toFixed(count >= 10000 ? 0 : 1)}k`;
  return String(count);
}

const nameOverrides: Record<string, string> = {
  "rose-pine": "Rosé Pine",
  "retro-82": "Retro 82",
  "catppuccin-latte": "Catppuccin Latte",
  "flexoki-light": "Flexoki Light",
};

function titleCase(text: string): string {
  return text
    .split(/[-_\s]+/)
    .filter(Boolean)
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(" ");
}

export function prettyTheme(id: string): string {
  return nameOverrides[id] ?? titleCase(id);
}

/** "1-the-backwater.jpg" reads as "The backwater"; a bare number keeps the theme's name. */
export function prettyWallpaper(file: string, themeName: string): string {
  const base = file.replace(/\.[a-z0-9]+$/i, "").replace(/^\d+-/, "");
  const numeric = /^(bg)?(\d+)$/i.exec(base);
  if (numeric) return `${themeName} No. ${Number(numeric[2])}`;
  if (base === "wall") return `${themeName} classic`;
  const words = titleCase(base);
  return words.charAt(0) + words.slice(1).toLowerCase();
}

/** Two soft glows over the theme's base, for artwork that is missing or still loading. */
export function gradient(colours: readonly string[]): string {
  const [base = "#18181b", , accent = "#818cf8", first = accent, second = accent] = colours;
  return `radial-gradient(120% 90% at 85% 10%, ${first}55, transparent 55%), radial-gradient(90% 80% at 10% 100%, ${second}44, transparent 60%), linear-gradient(135deg, ${base}, ${accent}33)`;
}

function themeColours(detail: ThemeDetail): string[] {
  const { colours, ring } = detail.summary;
  const accent = detail.values.borderActive ?? ring;
  return [
    colours?.background ?? "#18181b",
    colours?.foreground ?? "#e4e4e7",
    accent,
    colours?.red ?? accent,
    colours?.blue ?? accent,
  ];
}

function plural(count: number, word: string): string {
  return `${count} ${word}${count === 1 ? "" : "s"}`;
}

/** The wallpaper in use first, so a card shows what the theme looks like now. */
function orderedBackgrounds(detail: ThemeDetail) {
  const { backgrounds, currentBackground } = detail.summary;
  const current = backgrounds.find((background) => background.path === currentBackground);
  return current ? [current, ...backgrounds.filter((entry) => entry !== current)] : backgrounds;
}

export function installedTheme(detail: ThemeDetail): WorkshopItem {
  const { summary, values } = detail;
  const backgrounds = orderedBackgrounds(detail);
  const images: string[] = backgrounds.map((background) => background.thumbnail);
  if (images.length === 0 && summary.preview) images.push(summary.preview);
  return {
    id: `theme:${summary.name}`,
    kind: "theme",
    name: summary.title,
    author: "On this Mac",
    subtitle: `${plural(backgrounds.length, "wallpaper")}, pairs with ${values.nvimColorscheme ?? detail.defaultColourscheme} in Neovim.`,
    // Mock: a theme on this Mac has no download count until there is a catalogue.
    downloads: seededDownloads(summary.name, 900, 14000),
    images,
    colours: themeColours(detail),
    dark: summary.isDark,
    tags: ["installed", summary.isDark ? "dark" : "light"],
    local: true,
  };
}

export function installedWallpapers(detail: ThemeDetail): WorkshopItem[] {
  const { summary } = detail;
  const colours = themeColours(detail);
  return orderedBackgrounds(detail).map((background) => ({
    id: `wallpaper:${summary.name}/${background.path}`,
    kind: "wallpaper" as const,
    name: background.name,
    author: "On this Mac",
    subtitle: `From ${summary.title}.`,
    // Mock: as for installed themes.
    downloads: seededDownloads(`${summary.name}${background.path}`, 300, 6000),
    images: [background.thumbnail],
    colours,
    dark: summary.isDark,
    tags: [summary.title.toLowerCase(), "installed"],
    local: true,
    group: `theme:${summary.name}`,
  }));
}

function communityTheme(theme: CommunityTheme): WorkshopItem {
  return {
    id: `theme:${theme.id}`,
    kind: "theme",
    name: prettyTheme(theme.id),
    author: "Omarchy community",
    subtitle: theme.blurb,
    downloads: seededDownloads(theme.id, 2400, 38000),
    // The window cannot load remote images, so these show the palette instead.
    images: theme.backgrounds.map(() => undefined),
    colours: theme.colours,
    dark: theme.dark,
    tags: [...theme.tags, theme.dark ? "dark" : "light"],
  };
}

function communityWallpapers(theme: CommunityTheme): WorkshopItem[] {
  const themeName = prettyTheme(theme.id);
  return theme.backgrounds.map((file) => ({
    id: `wallpaper:${theme.id}/${file}`,
    kind: "wallpaper" as const,
    name: prettyWallpaper(file, themeName),
    author: "Omarchy community",
    subtitle: `From ${themeName}.`,
    downloads: seededDownloads(`${theme.id}/${file}`, 400, 9000),
    images: [undefined],
    colours: theme.colours,
    dark: theme.dark,
    tags: [themeName.toLowerCase(), ...theme.tags],
    group: `theme:${theme.id}`,
  }));
}

export interface Catalogue {
  all: WorkshopItem[];
  byKind: Record<Kind, WorkshopItem[]>;
  featured: WorkshopItem | undefined;
  /** Which image of the featured item the hero leads with. */
  featuredImage: number;
}

/**
 * The installed themes take the place of the community entry with the same
 * name, and bring their own wallpapers in place of the community ones.
 */
export function buildCatalogue(installed: readonly ThemeDetail[]): Catalogue {
  const local = new Map(installed.map((detail) => [detail.summary.name, detail]));
  const community = new Set(communityThemes.map((theme) => theme.id));

  // Mock: the community themes, layouts and bars stand in for a catalogue.
  const themes = [
    ...communityThemes.map((theme) => {
      const detail = local.get(theme.id);
      return detail ? installedTheme(detail) : communityTheme(theme);
    }),
    ...installed.filter((detail) => !community.has(detail.summary.name)).map(installedTheme),
  ];
  const wallpapers = [
    ...installed.flatMap(installedWallpapers),
    ...communityThemes.filter((theme) => !local.has(theme.id)).flatMap(communityWallpapers),
  ];
  const paint = (index: number) => themes[index % themes.length]?.colours ?? neutralColours;
  const layouts: WorkshopItem[] = layoutDesigns.map((design, index) => ({
    ...design,
    id: `layout:${design.id}`,
    kind: "layout" as const,
    downloads: seededDownloads(design.id, 600, 12000),
    images: [],
    colours: paint(index),
    dark: true,
  }));
  const bars: WorkshopItem[] = barDesigns.map((design, index) => ({
    ...design,
    id: `bar:${design.id}`,
    kind: "bar" as const,
    downloads: seededDownloads(design.id, 500, 9000),
    images: [],
    colours: paint(index * 3 + 2),
    dark: true,
  }));

  const lead = themes.find((item) => item.id === `theme:${featured.theme}`) ?? themes[0];
  return {
    all: [...themes, ...wallpapers, ...layouts, ...bars],
    byKind: { theme: themes, wallpaper: wallpapers, layout: layouts, bar: bars },
    featured: lead,
    featuredImage: lead && lead.images.length > featured.image ? featured.image : 0,
  };
}

export function matchesQuery(item: WorkshopItem, query: string): boolean {
  const needle = query.trim().toLowerCase();
  if (!needle) return true;
  return [item.name, item.author, item.subtitle, kindLabels[item.kind], ...item.tags]
    .join(" ")
    .toLowerCase()
    .includes(needle);
}

/** Every wallpaper from the same theme, so the dialog pages through them as one. */
export function siblingsOf(items: readonly WorkshopItem[], item: WorkshopItem): WorkshopItem[] {
  if (item.kind !== "wallpaper" || !item.group) return [];
  return items.filter((entry) => entry.kind === "wallpaper" && entry.group === item.group);
}

/** One step through a carousel, wrapping at either end. */
export function stepIndex(index: number, delta: number, count: number): number {
  if (count < 1) return 0;
  return (((index + delta) % count) + count) % count;
}

/** What the desktop really uses now: the applied theme and its wallpaper. */
export function appliedOnDesktop(
  installed: readonly ThemeDetail[],
  current: string | null,
): Partial<Record<Kind, string>> {
  const theme = installed.find((detail) => detail.summary.name === current);
  if (!theme) return {};
  const background = theme.summary.currentBackground;
  return {
    theme: `theme:${theme.summary.name}`,
    ...(background ? { wallpaper: `wallpaper:${theme.summary.name}/${background}` } : {}),
  };
}

const storageKey = "macarchy.workshop.installed";

/** What this page has pretended to install, kept between visits where storage allows. */
export function readInstalled(storage: Pick<Storage, "getItem"> | undefined): string[] {
  try {
    const parsed: unknown = JSON.parse(storage?.getItem(storageKey) ?? "[]");
    return Array.isArray(parsed)
      ? parsed.filter((entry): entry is string => typeof entry === "string")
      : [];
  } catch {
    return [];
  }
}

export function writeInstalled(
  storage: Pick<Storage, "setItem"> | undefined,
  installed: readonly string[],
): void {
  try {
    storage?.setItem(storageKey, JSON.stringify(installed));
  } catch {
    // Storage can be full or refused; the list then lasts until the window closes.
  }
}
