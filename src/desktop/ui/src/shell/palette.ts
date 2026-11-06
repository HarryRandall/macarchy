export type PaletteSection = "This page" | "Go to" | "Actions";

const sectionOrder: readonly PaletteSection[] = ["This page", "Go to", "Actions"];

export interface PaletteItem {
  id: string;
  label: string;
  /** Quiet text after the label, such as the group a page belongs to. */
  hint?: string;
  /** The shortcut that runs it outside the palette, such as "⇧⌘L". */
  keys?: string;
  section: PaletteSection;
  /** Other words it answers to, which are matched but never shown. */
  keywords?: readonly string[];
}

function words(text: string): string[] {
  return text.toLowerCase().split(/\s+/).filter(Boolean);
}

/** How well the label answers the query: 0 starts with it, 1 has a word starting with it, 2 neither. */
function rank(item: PaletteItem, query: string): number {
  const label = item.label.toLowerCase();
  if (label.startsWith(query)) return 0;
  return words(label).some((word) => word.startsWith(query)) ? 1 : 2;
}

/**
 * The items matching every word of the query, anywhere in the label, hint or
 * keywords, grouped by section. Within a section, labels that start with the
 * query come first; otherwise the given order holds.
 */
export function filterPalette<T extends PaletteItem>(items: readonly T[], query: string): T[] {
  const needle = query.trim().toLowerCase();
  const terms = words(needle);
  return items
    .map((item, index) => ({ item, index }))
    .filter(({ item }) => {
      const haystack = [item.label, item.hint ?? "", ...(item.keywords ?? [])]
        .join(" ")
        .toLowerCase();
      return terms.every((term) => haystack.includes(term));
    })
    .map((entry) => ({ ...entry, rank: needle ? rank(entry.item, needle) : 0 }))
    .toSorted(
      (a, b) =>
        sectionOrder.indexOf(a.item.section) - sectionOrder.indexOf(b.item.section) ||
        a.rank - b.rank ||
        a.index - b.index,
    )
    .map(({ item }) => item);
}

/** Runs of consecutive items in one section, each item with its place in the flat list. */
export function groupPalette<T extends PaletteItem>(
  items: readonly T[],
): { section: PaletteSection; items: { item: T; index: number }[] }[] {
  const groups: { section: PaletteSection; items: { item: T; index: number }[] }[] = [];
  items.forEach((item, index) => {
    const last = groups.at(-1);
    if (last?.section === item.section) last.items.push({ item, index });
    else groups.push({ section: item.section, items: [{ item, index }] });
  });
  return groups;
}

/** Moves a highlight by `step`, wrapping at either end. */
export function stepIndex(index: number, step: number, length: number): number {
  if (length === 0) return 0;
  return (((index + step) % length) + length) % length;
}
