import type { LogEntry } from "~/bridge/protocol";

/** Who a log line is about: Macarchy itself or one of the desktop services. */
export type LogSource = "macarchy" | "yabai" | "sketchybar" | "borders" | "skhd";
export type LogLevel = "info" | "error";

export const logSources: readonly LogSource[] = [
  "macarchy",
  "yabai",
  "sketchybar",
  "borders",
  "skhd",
];

const sourceByCategory: Record<LogEntry["category"], LogSource> = {
  "Menu Bar": "sketchybar",
  Borders: "borders",
  Layout: "yabai",
  "Window Rules": "yabai",
  Shortcuts: "skhd",
  Themes: "macarchy",
  Backups: "macarchy",
  System: "macarchy",
};

export function logSource(entry: LogEntry): LogSource {
  return sourceByCategory[entry.category];
}

export function logLevel(entry: LogEntry): LogLevel {
  return entry.ok ? "info" : "error";
}

export interface LogFilter {
  source: LogSource | "all";
  level: LogLevel | "all";
  query: string;
}

export function filterLog(entries: readonly LogEntry[], filter: LogFilter): LogEntry[] {
  const terms = filter.query.toLowerCase().split(/\s+/).filter(Boolean);
  return entries.filter((entry) => {
    if (filter.source !== "all" && logSource(entry) !== filter.source) return false;
    if (filter.level !== "all" && logLevel(entry) !== filter.level) return false;
    const text = `${entry.command}\n${entry.detail}`.toLowerCase();
    return terms.every((term) => text.includes(term));
  });
}

export function countBySource(entries: readonly LogEntry[]): Record<LogSource, number> {
  const counts: Record<LogSource, number> = {
    macarchy: 0,
    yabai: 0,
    sketchybar: 0,
    borders: 0,
    skhd: 0,
  };
  for (const entry of entries) counts[logSource(entry)] += 1;
  return counts;
}

/** Failures the person has not seen with the panel open, behind the Logs button's dot. */
export function unreadFailures(entries: readonly LogEntry[], seen: ReadonlySet<string>): number {
  return entries.filter((entry) => !entry.ok && !seen.has(entry.id)).length;
}

/** Oldest first, as a terminal scrolls; entries in the same second keep the host's order. */
export function chronological(entries: readonly LogEntry[]): LogEntry[] {
  return entries
    .map((entry, index) => ({ entry, index }))
    .toSorted((a, b) => a.entry.at - b.entry.at || a.index - b.index)
    .map(({ entry }) => entry);
}

/** One entry as plain text for the clipboard, with its output indented below. */
export function logText(entry: LogEntry, time: string): string {
  const head = `${time} ${logLevel(entry).toUpperCase()} [${logSource(entry)}] ${entry.command}`;
  const detail = entry.detail.trim();
  return detail ? `${head}\n${detail.replace(/^/gm, "    ")}` : head;
}

/** The panel's height, kept between a usable minimum and leaving room for the page above it. */
export function clampLogHeight(height: number, available: number): number {
  const minimum = 140;
  const maximum = Math.max(minimum, available - 160);
  return Math.round(Math.min(Math.max(height, minimum), maximum));
}
