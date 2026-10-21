import { describe, expect, it } from "vitest";
import type { LogEntry } from "~/bridge/protocol";
import { commandText, recentActivity, relativeTime } from "./home-activity";

const now = 1_800_000_000;

function entry(id: string, at: number, patch: Partial<LogEntry> = {}): LogEntry {
  return {
    id,
    command: "/opt/homebrew/bin/yabai -m config layout bsp",
    detail: "",
    ok: true,
    at,
    status: 0,
    category: "Layout",
    ...patch,
  };
}

describe("relativeTime", () => {
  it("reads in the largest whole unit", () => {
    expect(relativeTime(null, now)).toBe("Never");
    expect(relativeTime(now - 30, now)).toBe("Just now");
    expect(relativeTime(now + 30, now)).toBe("Just now");
    expect(relativeTime(now - 5 * 60, now)).toMatch(/^5 min\.? ago$/);
    expect(relativeTime(now - 3 * 3600, now)).toMatch(/^3 hr\.? ago$/);
    expect(relativeTime(now - 2 * 86400, now)).toBe("2 days ago");
  });
});

describe("commandText", () => {
  it("drops the executable's folder", () => {
    expect(commandText("/opt/homebrew/bin/yabai -m space")).toBe("yabai -m space");
    expect(commandText("borders width=6")).toBe("borders width=6");
    expect(commandText("  skhd --reload ")).toBe("skhd --reload");
  });
});

describe("recentActivity", () => {
  it("keeps the newest entries, newest first", () => {
    const entries = [1, 2, 3, 4, 5, 6, 7].map((n) => entry(String(n), now - (7 - n) * 60));
    const recent = recentActivity(entries, now);
    expect(recent.map((item) => item.id)).toEqual(["7", "6", "5", "4", "3"]);
    expect(recent[0]).toMatchObject({ when: "Just now", command: "yabai -m config layout bsp" });
  });

  it("keeps only the first line of the output and the outcome", () => {
    const [item] = recentActivity(
      [entry("1", now, { detail: "\nNo such window\nexit 1", ok: false })],
      now,
    );
    expect(item).toMatchObject({ detail: "No such window", ok: false });
  });
});
