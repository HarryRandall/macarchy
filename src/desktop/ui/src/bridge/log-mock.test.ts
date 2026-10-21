import { describe, expect, it, vi } from "vitest";

import { createLogMock, logLimit } from "./log-mock";
import type { LogEntry } from "./protocol";

const categories: LogEntry["category"][] = [
  "Menu Bar",
  "Borders",
  "Themes",
  "Shortcuts",
  "Window Rules",
  "Layout",
  "Backups",
  "System",
];

const seed = { command: "note", detail: "", ok: true, status: null, category: "System" } as const;

describe("mock log", () => {
  it("starts with a dozen entries in every category, oldest first", () => {
    const log = createLogMock(
      () => 1_000_000,
      () => {},
    );
    const entries = log.entries();
    expect(entries).toHaveLength(12);
    expect(new Set(entries.map((entry) => entry.category))).toEqual(new Set(categories));
    const times = entries.map((entry) => entry.at);
    expect(times).toEqual(times.toSorted((a, b) => a - b));
    expect(times.every((at) => at < 1_000_000)).toBe(true);
    expect(new Set(entries.map((entry) => entry.id)).size).toBe(entries.length);
  });

  it("appends newest last with a fresh id and reports each change", () => {
    const changed = vi.fn<() => void>();
    const log = createLogMock(() => 2_000_000, changed);
    const ids = new Set(log.entries().map((entry) => entry.id));
    log.append(seed);
    const latest = log.entries().at(-1);
    expect(latest).toMatchObject({ ...seed, at: 2_000_000 });
    expect(ids.has(latest!.id)).toBe(false);
    log.clear();
    expect(log.entries()).toEqual([]);
    expect(changed).toHaveBeenCalledTimes(2);
  });

  it("keeps only the newest entries, as the host does", () => {
    const log = createLogMock(
      () => 0,
      () => {},
    );
    for (let index = 0; index < logLimit; index += 1) {
      log.append({ ...seed, command: `note ${index}` });
    }
    const entries = log.entries();
    expect(entries).toHaveLength(logLimit);
    expect(entries[0]?.command).toBe("note 0");
    expect(entries.at(-1)?.command).toBe(`note ${logLimit - 1}`);
  });
});
