import { type Plugin, type PluginCategory, pluginCategories } from "./plugins-mock";

export type PluginView = "All" | PluginCategory;

/** A card's footprint in the three-column grid. */
export type CardShape = "normal" | "wide" | "tall" | "full";

export interface PluginGroup {
  category: PluginCategory;
  items: Plugin[];
  shapes: CardShape[];
}

export interface PluginLayout {
  /** Plugins matching the view and the query, featured ones included. */
  total: number;
  /** Empty once anything is filtered, so the featured pair never hides a match. */
  featured: Plugin[];
  groups: PluginGroup[];
}

export function matchesQuery(plugin: Plugin, query: string): boolean {
  const words = query.trim().toLowerCase();
  if (!words) return true;
  return `${plugin.name} ${plugin.detail} ${plugin.author}`.toLowerCase().includes(words);
}

/**
 * Mixes in wide and tall cards so every row of three columns comes out
 * full: three becomes one tall beside two, and a remainder of one or two
 * widens the first card, then the last.
 */
export function bento(count: number): CardShape[] {
  if (count <= 0) return [];
  if (count === 1) return ["full"];
  if (count === 3) return ["tall", "normal", "normal"];
  const shapes: CardShape[] = Array.from({ length: count }, () => "normal");
  const wides = (3 - (count % 3)) % 3;
  if (wides >= 1) shapes[0] = "wide";
  if (wides === 2) shapes[count - 1] = "wide";
  return shapes;
}

/** The sections the page draws for a view and a search. */
export function pluginLayout(
  list: readonly Plugin[],
  featuredIds: readonly string[],
  view: PluginView,
  query: string,
): PluginLayout {
  const visible = list.filter(
    (plugin) => (view === "All" || plugin.category === view) && matchesQuery(plugin, query),
  );
  const showFeatured = view === "All" && !query.trim();
  const featured = showFeatured
    ? featuredIds.flatMap((id) => list.filter((plugin) => plugin.id === id))
    : [];
  const categories = view === "All" ? pluginCategories : [view];
  const groups = categories
    .map((category) => {
      const items = visible.filter(
        (plugin) =>
          plugin.category === category && !(showFeatured && featuredIds.includes(plugin.id)),
      );
      return { category, items, shapes: bento(items.length) };
    })
    .filter((group) => group.items.length > 0);
  return { total: visible.length, featured, groups };
}

/** How many plugins each view holds, for the tab counts. */
export function viewCounts(list: readonly Plugin[]): Record<PluginView, number> {
  const counts = { All: list.length } as Record<PluginView, number>;
  for (const category of pluginCategories) {
    counts[category] = list.filter((plugin) => plugin.category === category).length;
  }
  return counts;
}

/** A stable hue for an author's initial avatar, from the name without its "@". */
export function authorHue(author: string): number {
  let hue = 0;
  for (const char of author.replace(/^@/, "")) hue = (hue * 31 + char.charCodeAt(0)) % 360;
  return hue;
}
