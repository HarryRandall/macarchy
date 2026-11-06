import { describe, expect, it } from "vitest";

import type { HealthState } from "~/bridge/protocol";

import {
  dailyResults,
  HISTORY_DAYS,
  historyDays,
  historyLabels,
  passRate,
  resultOf,
  runTimes,
} from "./health-mock";

const check = (
  id: string,
  status: HealthState["checks"][number]["status"],
): HealthState["checks"][number] => ({
  id,
  group: "Dependencies",
  title: id,
  status,
  detail: "",
  advice: null,
  command: null,
  file: null,
});

describe("health history mock", () => {
  it("maps statuses to results, counting unknown as a warning", () => {
    expect(["passed", "warning", "failed", "unknown"].map((s) => resultOf(s as never))).toEqual([
      "pass",
      "warn",
      "fail",
      "warn",
    ]);
  });

  it("ends every series on the real result and repeats itself", () => {
    const failing = dailyResults("Services/skhd", "failed");
    expect(failing).toHaveLength(HISTORY_DAYS);
    expect(failing.at(-1)).toBe("fail");
    expect(failing.at(-2)).toBe("fail");
    expect(dailyResults("Services/skhd", "failed")).toEqual(failing);
    expect(dailyResults("Dependencies/yabai", "passed").at(-1)).toBe("pass");
  });

  it("keeps run times positive and near each check's own figure", () => {
    const times = runTimes("Dependencies/yabai");
    expect(times).toHaveLength(HISTORY_DAYS);
    const base = times.at(-1)!;
    expect(times.every((ms) => ms > 0 && ms >= base * 0.75 && ms <= base * 1.25)).toBe(true);
  });

  it("sums each day's results across checks and today counts one run", () => {
    const checks = [check("a", "passed"), check("b", "failed"), check("c", "warning")];
    const days = historyDays(checks);
    expect(days).toHaveLength(HISTORY_DAYS);
    expect(days.at(-1)).toEqual({ runs: 1, pass: 1, warn: 1, fail: 1 });
    for (const day of days) expect(day.pass + day.warn + day.fail).toBe(day.runs * checks.length);
    expect(passRate([{ runs: 1, pass: 3, warn: 1, fail: 0 }])).toBe(75);
    expect(passRate([])).toBe(100);
  });

  it("labels the fortnight ending on the day of the last run", () => {
    const labels = historyLabels(new Date(2026, 9, 21, 9, 30).getTime() / 1000);
    expect(labels[0]).toEqual({ short: "8 Oct", long: "Thu 8 Oct" });
    expect(labels.at(-2)).toEqual({ short: "20 Oct", long: "Yesterday" });
    expect(labels.at(-1)).toEqual({ short: "Today", long: "Today" });
  });
});
