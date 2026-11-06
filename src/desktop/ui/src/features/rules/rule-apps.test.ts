import { describe, expect, it } from "vitest";

import type { RulesState } from "~/bridge/protocol";

import { gridStep, knownApps, matchApps, sortedNames } from "./rule-apps";

const state: RulesState = {
  floatingApps: ["Messages", "calculator"],
  customRules: [{ id: "a", app: "Finder", title: "^Copy$" }],
  externalRules: [{ app: "System Settings", title: "" }],
  icons: { Messages: "icon://messages", Ghostty: "icon://ghostty" },
  unavailableReason: null,
};

describe("rule apps", () => {
  it("collects every named app once, sorted without regard to case", () => {
    expect(knownApps(state, ["Ghostty", " Slack ", ""])).toEqual([
      "calculator",
      "Finder",
      "Ghostty",
      "Messages",
      "Slack",
      "System Settings",
    ]);
    expect(sortedNames(["b", "A", "c"])).toEqual(["A", "b", "c"]);
  });

  it("matches part of a name and leaves out apps already used", () => {
    const apps = ["Finder", "Ghostty", "Messages"];
    expect(matchApps(apps, "  gh ")).toEqual(["Ghostty"]);
    expect(matchApps(apps, "", ["Finder"])).toEqual(["Ghostty", "Messages"]);
    expect(matchApps(apps, "zzz")).toEqual([]);
  });

  it("moves through a three-column grid of nine", () => {
    expect(gridStep(2, "ArrowRight", 9, 3)).toBe(3);
    expect(gridStep(8, "ArrowRight", 9, 3)).toBe(0);
    expect(gridStep(0, "ArrowLeft", 9, 3)).toBe(8);
    expect(gridStep(1, "ArrowDown", 9, 3)).toBe(4);
    expect(gridStep(7, "ArrowDown", 9, 3)).toBe(7);
    expect(gridStep(1, "ArrowUp", 9, 3)).toBe(1);
    expect(gridStep(5, "End", 9, 3)).toBe(8);
    expect(gridStep(5, "Home", 9, 3)).toBe(0);
    expect(gridStep(5, "Enter", 9, 3)).toBeUndefined();
    expect(gridStep(0, "ArrowRight", 0, 3)).toBeUndefined();
  });
});
