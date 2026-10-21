/**
 * Check history from the Studio design. Setup health only knows the latest
 * run, so past days and run times are generated from each check's id until
 * the host keeps a history. Today is always the real result. Each use is
 * marked `Mock:`.
 */

import type { HealthState } from "~/bridge/protocol";

export type Result = "pass" | "warn" | "fail";
type CheckStatus = HealthState["checks"][number]["status"];

export const HISTORY_DAYS = 14;

/** Full runs of every check on each of the 13 days before today. */
const runsPerDay = [1, 2, 1, 1, 3, 1, 2, 1, 1, 2, 1, 1, 3];

/** How a check's status reads in history. A check that could not run counts as a warning. */
export function resultOf(status: CheckStatus): Result {
  if (status === "passed") return "pass";
  if (status === "failed") return "fail";
  return "warn";
}

/** Deterministic noise in [0, 1), so the sample is the same on every render. */
function noise(seed: number, index: number) {
  const value = Math.sin(seed * 12.9898 + index * 78.233) * 43758.5453;
  return value - Math.floor(value);
}

function seedOf(id: string) {
  let hash = 7;
  for (const char of id) hash = (hash * 31 + char.charCodeAt(0)) % 100_003;
  return hash;
}

/**
 * One result per day, oldest first, ending with today's. A check failing
 * now has been failing for a few days, as a real fault would; others pass
 * with the odd warning.
 */
export function dailyResults(id: string, today: CheckStatus): Result[] {
  const seed = seedOf(id);
  const now = resultOf(today);
  const streak = now === "pass" ? 0 : 1 + Math.floor(noise(seed, 99) * 4);
  const past = Array.from({ length: HISTORY_DAYS - 1 }, (_, index): Result => {
    if (index >= HISTORY_DAYS - 1 - streak) return now;
    return noise(seed, index) > 0.93 ? "warn" : "pass";
  });
  return [...past, now];
}

/** Milliseconds each day's run took, around a stable figure per check. */
export function runTimes(id: string): number[] {
  const seed = seedOf(id);
  const base = 40 + Math.round(noise(seed, 50) * 260);
  return Array.from({ length: HISTORY_DAYS }, (_, index) =>
    index === HISTORY_DAYS - 1 ? base : Math.round(base * (0.78 + 0.44 * noise(seed, index))),
  );
}

interface Day {
  runs: number;
  pass: number;
  warn: number;
  fail: number;
}

/** Results summed per day across every check, counting each run. Today is one run. */
export function historyDays(checks: readonly HealthState["checks"][number][]): Day[] {
  const results = checks.map((check) => dailyResults(check.id, check.status));
  return Array.from({ length: HISTORY_DAYS }, (_, day) => {
    const runs = runsPerDay[day] ?? 1;
    const on = (result: Result) => runs * results.filter((series) => series[day] === result).length;
    return { runs, pass: on("pass"), warn: on("warn"), fail: on("fail") };
  });
}

/** The share of all check results that passed, as a whole percentage. */
export function passRate(days: readonly Day[]): number {
  const passed = days.reduce((sum, day) => sum + day.pass, 0);
  const all = days.reduce((sum, day) => sum + day.pass + day.warn + day.fail, 0);
  return all ? Math.round((100 * passed) / all) : 100;
}

const dayFormat = new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "short" });
const longDayFormat = new Intl.DateTimeFormat("en-GB", {
  weekday: "short",
  day: "numeric",
  month: "short",
});

/** Names for the history's days, ending on the day the checks last ran. */
export function historyLabels(checkedAt: number) {
  const last = new Date(checkedAt * 1000);
  return Array.from({ length: HISTORY_DAYS }, (_, index) => {
    const back = HISTORY_DAYS - 1 - index;
    const date = new Date(last.getFullYear(), last.getMonth(), last.getDate() - back);
    return {
      short: back === 0 ? "Today" : dayFormat.format(date),
      long: back === 0 ? "Today" : back === 1 ? "Yesterday" : longDayFormat.format(date),
    };
  });
}
