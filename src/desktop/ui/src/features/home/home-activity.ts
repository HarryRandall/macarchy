import type { LogEntry } from "~/bridge/protocol";

const relative = new Intl.RelativeTimeFormat("en-GB", { style: "short" });

/** "Just now", "5 min ago", "3 hr ago", "2 days ago", or "Never" without a time. */
export function relativeTime(at: number | null, now: number): string {
  if (at === null) return "Never";
  const minutes = Math.max(0, Math.floor((now - at) / 60));
  if (minutes === 0) return "Just now";
  if (minutes < 60) return relative.format(-minutes, "minute");
  if (minutes < 1440) return relative.format(-Math.floor(minutes / 60), "hour");
  return relative.format(-Math.floor(minutes / 1440), "day");
}

/** The command with its executable reduced to a name: `/opt/homebrew/bin/yabai -m` reads `yabai -m`. */
export function commandText(command: string): string {
  const [executable = "", ...rest] = command.trim().split(/\s+/);
  const name = executable.slice(executable.lastIndexOf("/") + 1);
  return [name || executable, ...rest].join(" ");
}

export interface Activity {
  id: string;
  when: string;
  command: string;
  /** The first line of the output, if any. */
  detail: string;
  ok: boolean;
  category: LogEntry["category"];
}

/** The newest `limit` entries, newest first. */
export function recentActivity(entries: readonly LogEntry[], now: number, limit = 5): Activity[] {
  return entries
    .toSorted((a, b) => b.at - a.at)
    .slice(0, limit)
    .map((entry) => ({
      id: entry.id,
      when: relativeTime(entry.at, now),
      command: commandText(entry.command),
      detail: entry.detail.trim().split("\n", 1)[0] ?? "",
      ok: entry.ok,
      category: entry.category,
    }));
}
