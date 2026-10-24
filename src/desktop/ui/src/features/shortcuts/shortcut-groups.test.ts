import { describe, expect, it } from "vitest";

import type { ShortcutBinding } from "~/bridge/protocol";

import {
  chordKey,
  findConflicts,
  groupByCategory,
  shortcutCategory,
  shortcutTitle,
} from "./shortcut-groups";
import { dayLabels, mostUsed } from "./usage-mock";

function binding(patch: Partial<ShortcutBinding> = {}): ShortcutBinding {
  return {
    id: 1,
    modifiers: ["ctrl", "alt"],
    key: "h",
    caps: ["⌃", "⌥", "H"],
    section: null,
    command: "echo custom",
    passthrough: false,
    appOverrides: [],
    modes: [],
    activatesMode: null,
    disabled: false,
    ...patch,
  };
}

describe("shortcut categories", () => {
  it.each([
    ["yabai -m window --focus west", "Windows"],
    ["yabai -m window --toggle zoom-fullscreen", "Windows"],
    ["yabai -m space --focus 3", "Workspaces"],
    ["yabai -m window --space 2 && yabai -m space --focus 2", "Workspaces"],
    ['"$HOME/.config/macarchy/Macarchy.app/Contents/MacOS/macarchy" theme next', "Macarchy"],
    ["open -na Ghostty 2>/dev/null || open -na Terminal", "Apps"],
    ["echo custom", "Other"],
  ])("files %s under %s", (command, category) => {
    expect(shortcutCategory(binding({ command }))).toBe(category);
  });

  it("treats per-app bindings as apps and keeps the tab order", () => {
    const perApp = binding({ id: 2, command: "", appOverrides: [{ app: "Finder", command: "x" }] });
    const focus = binding({ id: 3, command: "yabai -m window --focus east" });
    expect(shortcutCategory(perApp)).toBe("Apps");
    expect(groupByCategory([perApp, focus]).map((group) => group.category)).toEqual([
      "Windows",
      "Apps",
    ]);
  });
});

describe("shortcut titles", () => {
  it("names a command it cannot describe by its skhdrc group, keeping the command", () => {
    const grow = binding({
      section: "Grow and shrink",
      command: "yabai -m window --ratio rel:0.05",
    });
    const shrink = binding({
      id: 2,
      section: "Grow and shrink",
      command: "yabai -m window --ratio rel:-0.05",
    });
    expect(shortcutTitle(grow, [grow, shrink])).toEqual({
      title: "Grow and shrink",
      command: "yabai -m window --ratio rel:0.05",
    });
    const left = binding({ command: "yabai -m window --focus west" });
    expect(shortcutTitle(left, [left, shrink])).toEqual({ title: "Focus left", command: null });
    const bare = binding({ command: "echo bare" });
    expect(shortcutTitle(bare, [bare])).toEqual({ title: "echo bare", command: "echo bare" });
  });
});

describe("conflicts", () => {
  it("counts left and right modifiers and hyper as the same keys", () => {
    expect(chordKey(["lcmd", "shift"], "K")).toBe(chordKey(["shift", "cmd"], "k"));
    expect(chordKey(["hyper"], "a")).toBe(chordKey(["ctrl", "alt", "shift", "cmd"], "a"));
  });

  it("reports duplicates both ways and chords macOS keeps", () => {
    const one = binding({ section: "Launch", command: "open -a Ghostty" });
    const two = binding({
      id: 2,
      modifiers: ["alt", "ctrl"],
      section: "Notes",
      command: "open -a Notes",
    });
    const spotlight = binding({ id: 3, modifiers: ["cmd"], key: "space", caps: ["⌘", "Space"] });
    const free = binding({ id: 4, key: "j" });
    const conflicts = findConflicts([one, two, spotlight, free]);
    expect(conflicts.get(1)).toBe('Same keys as "Notes"');
    expect(conflicts.get(2)).toBe('Same keys as "Launch"');
    expect(conflicts.get(3)).toBe("macOS uses ⌘ Space for Spotlight");
    expect(conflicts.has(4)).toBe(false);
  });

  it("lets a disabled binding hold no chord", () => {
    const live = binding({ command: "echo live" });
    const off = binding({ id: 2, command: "echo off", disabled: true });
    expect(findConflicts([live, off]).size).toBe(0);
  });

  it("compares chords only within the same skhd mode", () => {
    const plain = binding({ command: "echo plain" });
    const resize = binding({ id: 2, command: "echo resize", modes: ["resize"] });
    const both = binding({ id: 3, command: "echo both", modes: ["resize", "move"] });
    const conflicts = findConflicts([plain, resize, both]);
    expect(conflicts.has(1)).toBe(false);
    expect(conflicts.get(2)).toBe('Same keys as "echo both (resize, move mode)"');
  });
});

describe("usage mock", () => {
  it("sums a group's bindings and lists the busiest first, the same every time", () => {
    const bindings = [
      binding({ section: "Switch to desktop", key: "1" }),
      binding({ id: 2, section: "Switch to desktop", key: "2" }),
      binding({ id: 3, section: "Open a terminal", key: "return" }),
    ];
    const first = mostUsed(bindings);
    expect(first.map((item) => item.name).toSorted()).toEqual([
      "Open a terminal",
      "Switch to desktop",
    ]);
    expect(first[0]!.count).toBeGreaterThanOrEqual(first[1]!.count);
    expect(mostUsed(bindings)).toEqual(first);
    expect(mostUsed(bindings, 1)).toHaveLength(1);
  });

  it("names the days up to today", () => {
    const labels = dayLabels(new Date(2026, 9, 21, 12), 3);
    expect(labels.map((label) => label.short)).toEqual(["19 Oct", "20 Oct", "Today"]);
    expect(labels.map((label) => label.long)).toEqual(["Mon 19 Oct", "Yesterday", "Today"]);
  });
});
