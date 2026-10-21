import type { RulesState } from "~/bridge/protocol";

const byName = (a: string, b: string) => a.localeCompare(b, undefined, { sensitivity: "base" });

export function sortedNames(names: readonly string[]): string[] {
  return names.toSorted(byName);
}

/**
 * Every app the rules already know of, by name: the host's icons and the apps
 * named in floating, custom and external rules. There is no list of installed
 * apps, so this is what the workspace picker offers.
 */
export function knownApps(state: RulesState, extra: readonly string[] = []): string[] {
  const names = [
    ...Object.keys(state.icons),
    ...state.floatingApps,
    ...state.customRules.map((rule) => rule.app),
    ...state.externalRules.map((rule) => rule.app),
    ...extra,
  ]
    .map((name) => name.trim())
    .filter(Boolean);
  return sortedNames([...new Set(names)]);
}

/** Apps whose name contains the query, ignoring case, without those excluded. */
export function matchApps(
  apps: readonly string[],
  query: string,
  exclude: readonly string[] = [],
): string[] {
  const wanted = query.trim().toLowerCase();
  return apps.filter((app) => !exclude.includes(app) && app.toLowerCase().includes(wanted));
}

/**
 * Where an arrow key moves in a grid read left to right, or undefined when
 * the key does not move. Left and Right wrap through the rows, Up and Down
 * stay in the column, Home and End go to the first and last cell.
 */
export function gridStep(
  index: number,
  key: string,
  count: number,
  columns: number,
): number | undefined {
  if (count <= 0) return undefined;
  switch (key) {
    case "ArrowRight":
      return (index + 1) % count;
    case "ArrowLeft":
      return (index - 1 + count) % count;
    case "ArrowDown":
      return index + columns < count ? index + columns : index;
    case "ArrowUp":
      return index - columns >= 0 ? index - columns : index;
    case "Home":
      return 0;
    case "End":
      return count - 1;
    default:
      return undefined;
  }
}
