/** Days in the backups chart; the last is today. */
export const chartDays = 30;

/** Midnight at the start of each of the last `days` calendar days, oldest first. */
export function dayStarts(now: number, days = chartDays): number[] {
  return Array.from({ length: days }, (_, index) => {
    const day = new Date(now);
    day.setHours(0, 0, 0, 0);
    // setDate rather than subtracting hours, so a daylight saving change keeps days whole.
    day.setDate(day.getDate() - (days - 1 - index));
    return day.getTime();
  });
}

/** The day a moment falls on, or null before the first. Later moments count as the last day. */
export function dayOf(starts: readonly number[], time: number): number | null {
  const index = starts.findLastIndex((start) => time >= start);
  return index === -1 ? null : index;
}

export interface BackupDay {
  start: number;
  /** Snapshots taken that day. */
  count: number;
  /** Files those snapshots saved. */
  files: number;
}

/** Snapshots and the files they saved, per day over the chart's span. */
export function backupsByDay(
  snapshots: readonly { created: number; files: number }[],
  now: number,
  days = chartDays,
): BackupDay[] {
  const starts = dayStarts(now, days);
  const result = starts.map((start) => ({ start, count: 0, files: 0 }));
  for (const snapshot of snapshots) {
    const index = dayOf(starts, snapshot.created);
    const day = index === null ? undefined : result[index];
    if (!day) continue;
    day.count += 1;
    day.files += snapshot.files;
  }
  return result;
}

/** "Tue 21 Oct", for a chart's tooltip and filter chip. */
export function formatDay(time: number): string {
  return new Date(time).toLocaleDateString("en-GB", {
    weekday: "short",
    day: "numeric",
    month: "short",
  });
}

/** "21 Oct", for an axis label. */
export function formatShortDay(time: number): string {
  return new Date(time).toLocaleDateString("en-GB", { day: "numeric", month: "short" });
}

/** "Today, 17:02", "Yesterday, 21:40" or "18 Oct, 09:15". */
export function formatWhen(time: number, now: number): string {
  const [yesterday, today] = dayStarts(now, 2);
  const clock = new Date(time).toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" });
  if (today !== undefined && time >= today) return `Today, ${clock}`;
  if (yesterday !== undefined && time >= yesterday) return `Yesterday, ${clock}`;
  return `${formatShortDay(time)}, ${clock}`;
}

/** "Just now", "5 min ago", "2 hr ago" or "3 days ago". */
export function formatAgo(time: number, now: number): string {
  const minutes = Math.round((now - time) / 60_000);
  if (minutes < 1) return "Just now";
  const format = new Intl.RelativeTimeFormat("en-GB", { style: "short", numeric: "always" });
  if (minutes < 60) return format.format(-minutes, "minute");
  if (minutes < 1440) return format.format(-Math.round(minutes / 60), "hour");
  return format.format(-Math.round(minutes / 1440), "day");
}

/** A size given in KB, as "9.4 KB" or "1.2 MB". */
export function formatSize(kb: number): string {
  return kb >= 1000 ? `${(kb / 1024).toFixed(1)} MB` : `${kb.toFixed(1)} KB`;
}

/** A change in KB with its sign, as "+1.6 KB", "-0.5 KB" or "None". */
export function formatChange(kb: number): string {
  const rounded = Math.round(kb * 10) / 10;
  if (rounded === 0) return "None";
  return `${rounded > 0 ? "+" : ""}${rounded.toFixed(1)} KB`;
}

/** "1 file" or "3 files". */
export function plural(count: number, one: string, many = `${one}s`): string {
  return `${count} ${count === 1 ? one : many}`;
}
