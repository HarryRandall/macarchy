/**
 * Shortcut usage from the Studio design. skhd does not count key presses, so
 * these figures stand in until something does. Each use is marked `Mock:`.
 */

import type { ShortcutBinding } from "~/bridge/protocol";

import { shortcutTitle } from "./shortcut-groups";

/** Presses per day for the 14 days up to today; weekends run quieter. */
export const pressesPerDay: readonly number[] = [
  236, 214, 92, 78, 251, 268, 243, 259, 221, 104, 86, 274, 291, 162,
];

/** Stable presses for one action, so the list does not reshuffle between renders. */
function pressesFor(name: string) {
  let hash = 7;
  for (const char of name) hash = (hash * 31 + char.charCodeAt(0)) % 9973;
  return 24 + (hash % 280);
}

export interface UsageItem {
  /** The skhdrc group, or the row's name: what the search is set to on a click. */
  name: string;
  count: number;
}

/** The most pressed actions, summed over a group's bindings, busiest first. */
export function mostUsed(bindings: readonly ShortcutBinding[], limit = 5): UsageItem[] {
  const totals = new Map<string, number>();
  for (const binding of bindings) {
    const name = binding.section ?? shortcutTitle(binding, bindings).title;
    totals.set(name, (totals.get(name) ?? 0) + pressesFor(`${name}/${binding.key}`));
  }
  return [...totals]
    .map(([name, count]) => ({ name, count }))
    .toSorted((a, b) => b.count - a.count || a.name.localeCompare(b.name))
    .slice(0, limit);
}

const dayFormat = new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "short" });
const longDayFormat = new Intl.DateTimeFormat("en-GB", {
  weekday: "short",
  day: "numeric",
  month: "short",
});

/** Names for each of `days` days ending today, short for the axis and long for tooltips. */
export function dayLabels(today: Date, days: number) {
  return Array.from({ length: days }, (_, index) => {
    const back = days - 1 - index;
    const date = new Date(today.getFullYear(), today.getMonth(), today.getDate() - back);
    return {
      short: back === 0 ? "Today" : dayFormat.format(date),
      long: back === 0 ? "Today" : back === 1 ? "Yesterday" : longDayFormat.format(date),
    };
  });
}
