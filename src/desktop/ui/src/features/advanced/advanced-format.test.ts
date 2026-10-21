import { describe, expect, it } from "vitest";

import {
  backupsByDay,
  dayOf,
  dayStarts,
  formatAgo,
  formatChange,
  formatSize,
  formatWhen,
  plural,
} from "./advanced-format";

const now = new Date(2026, 9, 21, 18, 20).getTime();
const at = (day: number, hour: number, minute = 0) =>
  new Date(2026, 9, day, hour, minute).getTime();

describe("dayStarts", () => {
  it("ends on today's midnight and steps back a calendar day at a time", () => {
    const starts = dayStarts(now, 3);
    expect(starts).toEqual([at(19, 0), at(20, 0), at(21, 0)]);
  });

  it("keeps whole days across the end of daylight saving", () => {
    const starts = dayStarts(new Date(2026, 3, 6, 12).getTime(), 3);
    expect(starts.map((start) => new Date(start).getDate())).toEqual([4, 5, 6]);
    expect(starts.every((start) => new Date(start).getHours() === 0)).toBe(true);
  });
});

describe("backupsByDay", () => {
  it("counts snapshots and their files per day and drops older ones", () => {
    const days = backupsByDay(
      [
        { created: at(21, 17, 2), files: 3 },
        { created: at(21, 9, 31), files: 1 },
        { created: at(19, 11), files: 2 },
        { created: at(1, 11), files: 5 },
      ],
      now,
      3,
    );
    expect(days.map((day) => [day.count, day.files])).toEqual([
      [1, 2],
      [0, 0],
      [2, 4],
    ]);
  });

  it("files a snapshot from a clock ahead of this one under today", () => {
    const days = backupsByDay([{ created: at(22, 1), files: 1 }], now, 2);
    expect(days.at(-1)?.count).toBe(1);
  });
});

it("finds no day before the chart begins", () => {
  const starts = dayStarts(now, 2);
  expect(dayOf(starts, at(19, 23))).toBeNull();
  expect(dayOf(starts, at(20, 0))).toBe(0);
  expect(dayOf(starts, at(21, 18))).toBe(1);
});

it("names recent days and gives the date for older ones", () => {
  expect(formatWhen(at(21, 17, 2), now)).toBe("Today, 17:02");
  expect(formatWhen(at(20, 21, 40), now)).toBe("Yesterday, 21:40");
  expect(formatWhen(at(18, 9, 15), now)).toBe("18 Oct, 09:15");
});

it("says how long ago in the largest whole unit", () => {
  expect(formatAgo(now - 20_000, now)).toBe("Just now");
  expect(formatAgo(now - 5 * 60_000, now)).toMatch(/^5 min/);
  expect(formatAgo(now - 3 * 3_600_000, now)).toMatch(/^3 hr/);
  expect(formatAgo(now - 2 * 86_400_000, now)).toMatch(/^2 days/);
});

it("sizes in KB until a megabyte", () => {
  expect(formatSize(9.43)).toBe("9.4 KB");
  expect(formatSize(1184)).toBe("1.2 MB");
});

it("signs a change in size and calls a rounding-level change none", () => {
  expect(formatChange(1.6)).toBe("+1.6 KB");
  expect(formatChange(-0.5)).toBe("-0.5 KB");
  expect(formatChange(0.01)).toBe("None");
});

it("pluralises a count", () => {
  expect(plural(1, "file")).toBe("1 file");
  expect(plural(3, "file")).toBe("3 files");
});
