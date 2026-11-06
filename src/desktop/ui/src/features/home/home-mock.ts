/**
 * Stand-ins for Home figures Macarchy does not record yet: window counts,
 * focus time, service load and theme history, plus the menu bar and
 * floating-app summaries that live in pages Home does not read. Each use is
 * marked `Mock:`; replace them with real readings as they become available.
 */

export interface WorkspaceWindows {
  workspace: number;
  windows: number;
  apps: string;
}

export const workspaceWindows: readonly WorkspaceWindows[] = [
  { workspace: 1, windows: 4, apps: "Ghostty, Zed, Safari, Notes" },
  { workspace: 2, windows: 3, apps: "Safari, Slack, Mail" },
  { workspace: 3, windows: 2, apps: "Figma, Preview" },
  { workspace: 4, windows: 5, apps: "Ghostty (3), TablePlus, Docker" },
  { workspace: 5, windows: 1, apps: "Spotify" },
  { workspace: 6, windows: 0, apps: "" },
  { workspace: 7, windows: 2, apps: "Messages, FaceTime" },
  { workspace: 8, windows: 0, apps: "" },
  { workspace: 9, windows: 1, apps: "Activity Monitor" },
];

export interface FocusTime {
  app: string;
  minutes: number;
  sessions: number;
  workspace: number;
}

export const focusTime: readonly FocusTime[] = [
  { app: "Ghostty", minutes: 680, sessions: 41, workspace: 1 },
  { app: "Zed", minutes: 485, sessions: 23, workspace: 1 },
  { app: "Safari", minutes: 370, sessions: 58, workspace: 2 },
  { app: "Slack", minutes: 165, sessions: 74, workspace: 2 },
  { app: "Figma", minutes: 110, sessions: 9, workspace: 3 },
  { app: "Notes", minutes: 55, sessions: 17, workspace: 1 },
];

export const menuBarSummary = { position: "top", height: 35, items: 7 } as const;

export const floatingApps: readonly string[] = [
  "FaceTime",
  "Macarchy",
  "TablePlus",
  "iPhone Mirroring",
];

export interface MockDay {
  /** "Wed 21 Oct". */
  long: string;
  /** "21 Oct". */
  short: string;
  weekend: boolean;
}

const weekday = new Intl.DateTimeFormat("en-GB", { weekday: "short" });
const dayMonth = new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "short" });

/** The `count` days ending on `end`, oldest first. */
export function lastDays(end: Date, count: number): MockDay[] {
  return Array.from({ length: count }, (_, index) => {
    const day = new Date(end.getFullYear(), end.getMonth(), end.getDate() - (count - 1 - index));
    const short = dayMonth.format(day);
    return {
      long: `${weekday.format(day)} ${short}`,
      short,
      weekend: day.getDay() === 0 || day.getDay() === 6,
    };
  });
}

/** A repeatable sequence in [0, 1), so the charts look the same on every load. */
export function seeded(seed: number) {
  let state = seed;
  return () => {
    state = (state * 1664525 + 1013904223) % 4294967296;
    return state / 4294967296;
  };
}

export interface ServiceLoad {
  /** Per cent of one core. */
  cpu: number;
  /** Megabytes. */
  memory: number;
}

/** Daily CPU and memory of the services, quieter at weekends. */
export function serviceLoad(days: readonly MockDay[], seed = 783): ServiceLoad[] {
  const random = seeded(seed);
  return days.map((day, index) => ({
    cpu:
      Math.round(
        (1.7 + 0.5 * Math.sin(index / 3.2) + random() * 0.9 - (day.weekend ? 0.7 : 0)) * 10,
      ) / 10,
    memory: Math.round(
      188 + index * 1.1 + 12 * Math.sin(index / 4.5) + random() * 14 - (day.weekend ? 10 : 0),
    ),
  }));
}

/** Days back from today, and which installed themes were applied then by position. */
const changePattern: readonly [number, number[]][] = [
  [27, [0]],
  [24, [1, 2]],
  [20, [3]],
  [16, [4, 5, 6]],
  [15, [1]],
  [10, [2]],
  [6, [0, 3]],
  [3, [1]],
];

/**
 * Theme changes per day over `days`, using the installed themes' names, with
 * `current` applied today.
 */
export function themeChanges(
  days: readonly MockDay[],
  titles: readonly string[],
  current: string | null,
): { day: MockDay; themes: string[] }[] {
  const pick = (position: number) => (titles.length ? titles[position % titles.length]! : null);
  return days.map((day, index) => {
    const back = days.length - 1 - index;
    if (back === 0) return { day, themes: current ? [current] : [] };
    const positions = changePattern.find(([at]) => at === back)?.[1] ?? [];
    return {
      day,
      themes: positions.map(pick).filter((title): title is string => title !== null),
    };
  });
}

/** The name applied most often, or null when nothing was. */
export function mostApplied(changes: readonly { themes: readonly string[] }[]): string | null {
  const counts = new Map<string, number>();
  for (const change of changes)
    for (const theme of change.themes) counts.set(theme, (counts.get(theme) ?? 0) + 1);
  return [...counts].toSorted((a, b) => b[1] - a[1])[0]?.[0] ?? null;
}

/** "11h 20m", or "55m" under an hour. */
export function hoursAndMinutes(minutes: number): string {
  if (minutes < 60) return `${minutes}m`;
  return `${Math.floor(minutes / 60)}h ${String(minutes % 60).padStart(2, "0")}m`;
}
