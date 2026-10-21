import { describe, expect, it } from "vitest";

import type { LogEntry } from "~/bridge/protocol";

import {
  chronological,
  clampLogHeight,
  countBySource,
  filterLog,
  type LogFilter,
  logSource,
  logText,
  unreadFailures,
} from "./log-filter";

function entry(patch: Partial<LogEntry> & Pick<LogEntry, "id">): LogEntry {
  return {
    command: "yabai -m config layout bsp",
    detail: "",
    ok: true,
    at: 1_800_000_000,
    status: 0,
    category: "Layout",
    ...patch,
  };
}

const entries = [
  entry({ id: "1" }),
  entry({ id: "2", command: "sketchybar --reload", category: "Menu Bar" }),
  entry({
    id: "3",
    command: "borders width=4.0",
    detail: "Standard error:\nunknown option",
    ok: false,
    status: 1,
    category: "Borders",
  }),
  entry({ id: "4", command: "Applied theme Lumon", status: null, category: "Themes" }),
  entry({ id: "5", command: "skhd --reload", ok: false, status: 2, category: "Shortcuts" }),
];

const ids = (list: LogEntry[]) => list.map((item) => item.id);

describe("logSource", () => {
  it.each([
    ["Menu Bar", "sketchybar"],
    ["Borders", "borders"],
    ["Layout", "yabai"],
    ["Window Rules", "yabai"],
    ["Shortcuts", "skhd"],
    ["Themes", "macarchy"],
    ["Backups", "macarchy"],
    ["System", "macarchy"],
  ] as const)("files %s under %s", (category, source) => {
    expect(logSource(entry({ id: "x", category }))).toBe(source);
  });
});

describe("filterLog", () => {
  const shown = (filter: Partial<LogFilter>) =>
    ids(filterLog(entries, { source: "all", level: "all", query: "", ...filter }));

  it("keeps everything with no filter", () => {
    expect(shown({})).toEqual(["1", "2", "3", "4", "5"]);
  });

  it("narrows by source and level together", () => {
    expect(shown({ source: "borders" })).toEqual(["3"]);
    expect(shown({ level: "error" })).toEqual(["3", "5"]);
    expect(shown({ source: "yabai", level: "error" })).toEqual([]);
  });

  it("searches the command and its output for every word", () => {
    expect(shown({ query: "UNKNOWN" })).toEqual(["3"]);
    expect(shown({ query: "reload sketchy" })).toEqual(["2"]);
  });
});

describe("counts and unread failures", () => {
  it("counts entries per source", () => {
    expect(countBySource(entries)).toEqual({
      macarchy: 1,
      yabai: 1,
      sketchybar: 1,
      borders: 1,
      skhd: 1,
    });
  });

  it("counts only failures not yet seen", () => {
    expect(unreadFailures(entries, new Set())).toBe(2);
    expect(unreadFailures(entries, new Set(["3"]))).toBe(1);
    expect(unreadFailures(entries, new Set(ids(entries)))).toBe(0);
  });
});

describe("chronological", () => {
  it("sorts by time and keeps the host's order within a second", () => {
    const list = [
      entry({ id: "late", at: 30 }),
      entry({ id: "a", at: 10 }),
      entry({ id: "b", at: 10 }),
    ];
    expect(ids(chronological(list))).toEqual(["a", "b", "late"]);
  });
});

describe("logText", () => {
  it("writes the level, source and command, with output indented below", () => {
    expect(logText(entries[2] as LogEntry, "17:42:03")).toBe(
      "17:42:03 ERROR [borders] borders width=4.0\n    Standard error:\n    unknown option",
    );
    expect(logText(entries[0] as LogEntry, "17:41:58")).toBe(
      "17:41:58 INFO [yabai] yabai -m config layout bsp",
    );
  });
});

describe("clampLogHeight", () => {
  it("keeps the panel between its minimum and the room the page needs", () => {
    expect(clampLogHeight(80, 700)).toBe(140);
    expect(clampLogHeight(300, 700)).toBe(300);
    expect(clampLogHeight(900, 700)).toBe(540);
  });

  it("never goes below the minimum in a short window", () => {
    expect(clampLogHeight(300, 200)).toBe(140);
  });
});
