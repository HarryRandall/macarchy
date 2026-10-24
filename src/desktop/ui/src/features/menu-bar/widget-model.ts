import type {
  SettingValue,
  WidgetClick,
  WidgetInfo,
  WidgetMenuRow,
  WidgetRowType,
  WidgetSettingInfo,
  WidgetStyle,
} from "~/bridge/protocol";

import type { BarItem } from "./menu-bar-items";

/** What the preview shows a widget with. */
export type Sample = "live" | "widest" | "unavailable";

export const sampleOptions = [
  { value: "live" as const, label: "Live" },
  { value: "widest" as const, label: "Widest" },
  { value: "unavailable" as const, label: "Unavailable" },
];

export function widgetOf(item: BarItem, widgets: readonly WidgetInfo[]): WidgetInfo | null {
  return item.widget ? (widgets.find((widget) => widget.id === item.widget) ?? null) : null;
}

/** The widget's look with the item's changes over it. */
export function lookOf(item: BarItem, widget: WidgetInfo | null): WidgetStyle {
  return { ...widget?.style, ...item.style };
}

/** What a click does: the item's own, or else the widget's. */
export function clickOf(item: BarItem, widget: WidgetInfo | null): WidgetClick | null {
  return item.click ?? widget?.click ?? null;
}

export type ClickMode = "none" | "app" | "command" | "dropdown";

export function clickMode(click: WidgetClick | null): ClickMode {
  if (click?.dropdown) return "dropdown";
  if (click?.run !== undefined) return "command";
  if (click?.open !== undefined) return "app";
  return "none";
}

export function settingOf(item: BarItem, setting: WidgetSettingInfo): SettingValue | undefined {
  return item.settings[setting.key] ?? setting.default;
}

/**
 * The item with one setting changed. A value the same as the widget's
 * default is left out, so the item follows the widget if the default changes.
 */
export function withSetting(
  item: BarItem,
  setting: WidgetSettingInfo,
  value: SettingValue,
): Partial<BarItem> {
  const { [setting.key]: _old, ...rest } = item.settings;
  return { settings: value === setting.default ? rest : { ...rest, [setting.key]: value } };
}

/** The item with its look changed; a field set back to the widget's own is left out. */
export function withLook(
  item: BarItem,
  widget: WidgetInfo | null,
  patch: WidgetStyle,
): Partial<BarItem> {
  const merged: Record<string, unknown> = { ...item.style, ...patch };
  const own: Record<string, unknown> = { ...widget?.style };
  const kept = Object.fromEntries(
    Object.entries(merged).filter(([key, value]) => value !== undefined && value !== own[key]),
  );
  return { style: Object.keys(kept).length > 0 ? (kept as WidgetStyle) : null };
}

/** The item with a new click; the widget's own click again clears the change. */
export function withClick(widget: WidgetInfo | null, click: WidgetClick | null): Partial<BarItem> {
  const same = JSON.stringify(click ?? null) === JSON.stringify(widget?.click ?? null);
  return { click: same ? null : (click ?? {}) };
}

/** A fresh click of each kind, keeping what the current one has where it can. */
export function clickFor(mode: ClickMode, current: WidgetClick | null): WidgetClick | null {
  switch (mode) {
    case "none":
      return null;
    case "app":
      return { open: current?.open ?? "" };
    case "command":
      return { run: current?.run ?? "" };
    case "dropdown":
      return { dropdown: current?.dropdown ?? [{ type: "heading", label: "Heading" }] };
  }
}

/** Readings the preview fills a template with, so a dropdown reads as it will. */
const previewReadings: Record<string, string> = {
  weekday: "Fri",
  "weekday.long": "Friday",
  day: "23",
  month: "Oct",
  "month.long": "October",
  year: "2026",
  time: "3:41 PM",
  date: "Fri 23 Oct 3:41 PM",
  percent: "84%",
  load: "12.0%",
  temp: "52.4°",
};

/** A template with the readings the preview knows filled in; others stay as written. */
export function fill(template: string | undefined): string {
  return (template ?? "").replace(/\{([^{}]+)\}/g, (whole, name: string) => {
    if (previewReadings[name] !== undefined) return previewReadings[name];
    if (name.startsWith("time:")) return "5:41 AM";
    return whole;
  });
}

/**
 * What the widget shows for a sample: what the bar has now, its widest or
 * its unavailable text. A two-line widget's lines are split at `\n`.
 */
export function sampleText(item: BarItem, widget: WidgetInfo | null, sample: Sample): string {
  const widest = widget?.samples?.widest;
  if (sample === "unavailable") return widget?.samples?.unavailable ?? "--";
  if (sample === "widest") return widest ?? (item.reading || widget?.name || item.title);
  return item.reading || (widest ? fill(widget?.label) || widest : widget?.name || item.title);
}

export function sampleLines(text: string, style: WidgetStyle): [string, string] | null {
  if (style.lines !== 2) return null;
  const [first = "", second = ""] = text.split(/\n| {2,}/);
  return [first, second];
}

/** `day-month` as `Day month`, for options written as ids. */
export function humanise(option: string): string {
  const words = option.replace(/[-_]/g, " ");
  return words.charAt(0).toUpperCase() + words.slice(1);
}

const eventNames: Record<string, string> = {
  system_woke: "System wake",
  power_source_changed: "Power source changes",
  timezone_changed: "Time zone changes",
  space_changed: "Space changes",
  front_app_switched: "App switches",
  display_changed: "Display changes",
};

export function eventName(event: string): string {
  return eventNames[event] ?? humanise(event);
}

const units: Record<string, [string, string]> = {
  s: ["second", "seconds"],
  m: ["minute", "minutes"],
  h: ["hour", "hours"],
};

/** `2s` as `Every 2 seconds`, `minute` as `On the minute`. */
export function updateText(every: string | undefined): string {
  if (!every) return "Only when clicked";
  if (every === "minute") return "On the minute";
  if (every === "second") return "Every second";
  const match = /^(\d+)([smh])$/.exec(every);
  const unit = match ? units[match[2] ?? ""] : undefined;
  if (!match || !unit) return every;
  return match[1] === "1" ? `Every ${unit[0]}` : `Every ${match[1]} ${unit[1]}`;
}

export const rowTypes: { type: WidgetRowType; name: string }[] = [
  { type: "heading", name: "Heading" },
  { type: "reading", name: "Reading" },
  { type: "text", name: "Text" },
  { type: "action", name: "Action" },
  { type: "toggle", name: "Toggle" },
  { type: "choice", name: "Choice" },
  { type: "divider", name: "Divider" },
];

export function rowTypeName(type: WidgetRowType): string {
  return (
    rowTypes.find((entry) => entry.type === type)?.name ??
    { graph: "Graph", cores: "Cores", apps: "Apps" }[type as "graph"] ??
    type
  );
}

/** A new row of a type, with something in it to edit. */
export function newRow(type: WidgetRowType, settings: readonly WidgetSettingInfo[]): WidgetMenuRow {
  switch (type) {
    case "divider":
      return { type };
    case "reading":
      return { type, label: "Label", value: "{time}" };
    case "action":
      return { type, label: "Open an app", open: "" };
    case "toggle": {
      const setting = settings.find((entry) => entry.type === "toggle");
      return { type, label: setting?.label ?? "Setting", setting: setting?.key ?? "" };
    }
    case "choice": {
      const setting = settings.find((entry) => entry.type === "choice");
      return {
        type,
        label: setting?.label ?? "Choice",
        setting: setting?.key ?? "",
        options: setting?.options ?? [],
      };
    }
    default:
      return { type, label: type === "heading" ? "Heading" : "Text" };
  }
}

/** A row changed to another type, keeping its label. */
export function retype(
  row: WidgetMenuRow,
  type: WidgetRowType,
  settings: readonly WidgetSettingInfo[],
): WidgetMenuRow {
  if (row.type === type) return row;
  const fresh = newRow(type, settings);
  return type === "divider" ? fresh : { ...fresh, label: row.label ?? fresh.label };
}

export function moveRow(rows: WidgetMenuRow[], index: number, by: -1 | 1): WidgetMenuRow[] {
  const target = index + by;
  if (target < 0 || target >= rows.length) return rows;
  const next = [...rows];
  const [row] = next.splice(index, 1);
  if (row) next.splice(target, 0, row);
  return next;
}

/** Why a widget item cannot be applied yet, if it cannot. */
export function widgetProblem(item: BarItem, widget: WidgetInfo | null): string | null {
  if (item.kind !== "widget") return null;
  if (!widget) return `${item.title} needs a widget that is no longer here.`;
  const click = item.click;
  if (click?.open !== undefined && !click.open.trim()) return `${item.title} needs an app to open.`;
  if (click?.run !== undefined && !click.run.trim()) return `${item.title} needs a command to run.`;
  if (click?.dropdown?.length === 0) return `${item.title}'s dropdown needs a row.`;
  return null;
}
