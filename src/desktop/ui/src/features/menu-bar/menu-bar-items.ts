import type {
  BarItemKind,
  BarZone,
  MenuBarItemEdit,
  MenuBarItemState,
  MenuBarSettings,
} from "~/bridge/protocol";

export type Zone = BarZone;
export type BarItem = MenuBarItemState;

export const zones: readonly Zone[] = ["left", "centre", "right"];

export const zoneLabels: Record<Zone, string> = { left: "Left", centre: "Centre", right: "Right" };

/** Seconds between runs of a command item, as the page offers them. */
export const intervals = [
  { value: "1", label: "1s" },
  { value: "5", label: "5s" },
  { value: "30", label: "30s" },
  { value: "60", label: "1m" },
  { value: "300", label: "5m" },
] as const;

/** Glyphs a made item can show. SketchyBar draws them in SF Pro, so they render as here. */
export const glyphs = ["", "●", "○", "◆", "★", "▲", "■", "↑", "↓", "→", "⇅", "»"] as const;

/** Items the page can make, with what the library says about them. */
export const makeable: { kind: BarItemKind; name: string; detail: string }[] = [
  { kind: "text", name: "Text", detail: "A label you write" },
  { kind: "spacer", name: "Spacer", detail: "Empty width, to push items apart" },
  { kind: "command", name: "Command", detail: "Shows what a shell command prints" },
];

/** A new item for `zone`. Its id becomes a SketchyBar item name. */
export function newItem(kind: BarItemKind, zone: Zone, patch: Partial<BarItem> = {}): BarItem {
  const name = makeable.find((entry) => entry.kind === kind)?.name ?? "Item";
  return {
    id: `macarchy.${crypto.randomUUID().toLowerCase()}`,
    title: name,
    zone,
    visible: true,
    kind,
    text: kind === "text" ? "Hello" : "",
    icon: "",
    command: kind === "command" ? "" : null,
    interval: kind === "command" ? 30 : null,
    reading: "",
    ...patch,
  };
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
export function shiftZone(items: BarItem[], id: string, direction: -1 | 1): BarItem[] {
  const item = items.find((entry) => entry.id === id);
  if (!item) return items;
  const zone = zones[zones.indexOf(item.zone) + direction];
  return zone ? moveItem(items, id, zone) : items;
}

export function addItem(items: BarItem[], item: BarItem): BarItem[] {
  return insertAtZoneEnd(items, item);
}

/** Made items go; the bar's own can only be hidden. */
export function removeItem(items: BarItem[], id: string): BarItem[] {
  return items.filter((entry) => entry.id !== id || entry.kind === null);
}

export function patchItem(items: BarItem[], id: string, patch: Partial<BarItem>): BarItem[] {
  return items.map((entry) => (entry.id === id ? { ...entry, ...patch } : entry));
}

/** What the page sends back: the list without its readings. */
export function editsOf(items: BarItem[]): MenuBarItemEdit[] {
  return items.map(({ reading: _reading, ...edit }) => edit);
}

/** Every edited field, so an edit undone by hand no longer counts as a change. */
export function sameItems(a: BarItem[], b: BarItem[]): boolean {
  return JSON.stringify(editsOf(a)) === JSON.stringify(editsOf(b));
}

export function sameBar(a: MenuBarSettings, b: MenuBarSettings): boolean {
  return a.height === b.height && a.padding === b.padding && a.position === b.position;
}

/** Why an item cannot be applied yet, if it cannot. */
export function problemWith(item: BarItem): string | null {
  if (!item.title.trim()) return "Every item needs a name.";
  if (item.kind === "command" && !item.command?.trim()) return `${item.title} needs a command.`;
  return null;
}

/** What the preview and the list show for an item. */
export function shownText(item: BarItem): string {
  if (item.kind === "text") return item.text;
  if (item.kind === "command") return item.reading || "…";
  return item.reading;
}
