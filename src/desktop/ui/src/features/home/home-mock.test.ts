import { describe, expect, it } from "vitest";
import {
  hoursAndMinutes,
  lastDays,
  mostApplied,
  seeded,
  serviceLoad,
  themeChanges,
} from "./home-mock";

const today = new Date(2026, 9, 21);

describe("lastDays", () => {
  it("ends on the given day, oldest first", () => {
    const days = lastDays(today, 3);
    expect(days.map((day) => day.long)).toEqual(["Mon 19 Oct", "Tue 20 Oct", "Wed 21 Oct"]);
    expect(days[2]!.short).toBe("21 Oct");
  });

  it("marks weekends", () => {
    const days = lastDays(new Date(2026, 9, 19), 3);
    expect(days.map((day) => day.weekend)).toEqual([true, true, false]);
  });
});

describe("seeded", () => {
  it("repeats for the same seed and stays in range", () => {
    const first = seeded(7);
    const second = seeded(7);
    for (let index = 0; index < 20; index++) {
      const value = first();
      expect(value).toBe(second());
      expect(value).toBeGreaterThanOrEqual(0);
      expect(value).toBeLessThan(1);
    }
  });
});

describe("serviceLoad", () => {
  it("gives one reading per day and the same readings each time", () => {
    const days = lastDays(today, 30);
    const load = serviceLoad(days);
    expect(load).toHaveLength(30);
    expect(serviceLoad(days)).toEqual(load);
    for (const reading of load) {
      expect(reading.cpu).toBeGreaterThan(0);
      expect(reading.memory).toBeGreaterThan(150);
    }
  });
});

describe("themeChanges", () => {
  const days = lastDays(today, 30);

  it("applies the current theme today", () => {
    const changes = themeChanges(days, ["Lumon", "Awakening"], "Lumon");
    expect(changes.at(-1)!.themes).toEqual(["Lumon"]);
  });

  it("uses only the installed names, wrapping when there are few", () => {
    const changes = themeChanges(days, ["Lumon"], null);
    const names = new Set(changes.flatMap((change) => change.themes));
    expect([...names]).toEqual(["Lumon"]);
    expect(changes.at(-1)!.themes).toEqual([]);
  });

  it("is empty without themes", () => {
    expect(themeChanges(days, [], null).every((change) => change.themes.length === 0)).toBe(true);
  });
});

describe("mostApplied", () => {
  it("counts every application", () => {
    expect(mostApplied([{ themes: ["A", "B"] }, { themes: ["B"] }])).toBe("B");
    expect(mostApplied([{ themes: [] }])).toBeNull();
  });
});

describe("hoursAndMinutes", () => {
  it("pads minutes after hours", () => {
    expect(hoursAndMinutes(55)).toBe("55m");
    expect(hoursAndMinutes(605)).toBe("10h 05m");
  });
});
