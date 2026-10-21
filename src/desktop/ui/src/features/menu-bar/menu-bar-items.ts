import type { BarItem, LibraryItem, Zone } from "./menu-bar-mock";

export const zoneLabels: Record<Zone, string> = { left: "Left", centre: "Centre", right: "Right" };

export function zonesFor(centre: boolean): Zone[] {
  return centre ? ["left", "centre", "right"] : ["left", "right"];
}

function insertAtZoneEnd(items: BarItem[], item: BarItem): BarItem[] {
  const next = [...items];
  const last = next.map((entry) => entry.zone).lastIndexOf(item.zone);
  next.splice(last === -1 ? next.length : last + 1, 0, item);
  return next;
}

/** Moves an item into `zone`, before `beforeId` or after the zone's last item. */
export function moveItem(items: BarItem[], id: string, zone: Zone, beforeId?: string): BarItem[] {
  const item = items.find((entry) => entry.id === id);
  if (!item || id === beforeId) return items;
  const rest = items.filter((entry) => entry.id !== id);
  const moved = { ...item, zone };
  const at = beforeId ? rest.findIndex((entry) => entry.id === beforeId) : -1;
  if (at === -1) return insertAtZoneEnd(rest, moved);
  rest.splice(at, 0, moved);
  return rest;
}

/** One place earlier or later within the item's own zone, for the keyboard. */
export function stepItem(items: BarItem[], id: string, direction: -1 | 1): BarItem[] {
  const item = items.find((entry) => entry.id === id);
  if (!item) return items;
  const zone = items.filter((entry) => entry.zone === item.zone);
  const index = zone.findIndex((entry) => entry.id === id);
  const target = index + direction;
  if (target < 0 || target >= zone.length) return items;
  if (direction === -1) return moveItem(items, id, item.zone, zone[target]?.id);
  return moveItem(items, id, item.zone, zone[target + 1]?.id);
}

/** To the end of the neighbouring zone, for the keyboard; nothing past either edge. */
export function shiftZone(
  items: BarItem[],
  id: string,
  direction: -1 | 1,
  zones: readonly Zone[],
): BarItem[] {
  const item = items.find((entry) => entry.id === id);
  if (!item) return items;
  const zone = zones[zones.indexOf(item.zone) + direction];
  return zone ? moveItem(items, id, zone) : items;
}

export function addItem(items: BarItem[], item: BarItem): BarItem[] {
  return insertAtZoneEnd(items, item);
}

export function removeItem(items: BarItem[], id: string): BarItem[] {
  return items.filter((entry) => entry.id !== id);
}

export function patchItem(items: BarItem[], id: string, patch: Partial<BarItem>): BarItem[] {
  return items.map((entry) => (entry.id === id ? { ...entry, ...patch } : entry));
}

/** Items left in the centre zone while it is turned off, which the bar cannot show. */
export function hiddenInCentre(items: BarItem[], centre: boolean): number {
  return centre ? 0 : items.filter((entry) => entry.zone === "centre").length;
}

export function matchesLibrary(entry: LibraryItem, query: string): boolean {
  const needle = query.trim().toLowerCase();
  if (!needle) return true;
  return `${entry.name} ${entry.detail ?? ""} ${entry.category}`.toLowerCase().includes(needle);
}

/** Every field, so an edit undone by hand no longer counts as a change. */
export function sameItems(a: BarItem[], b: BarItem[]): boolean {
  return JSON.stringify(a) === JSON.stringify(b);
}
