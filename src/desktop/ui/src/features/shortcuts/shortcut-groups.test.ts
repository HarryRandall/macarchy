import { describe, expect, it } from "vitest";

import type { ShortcutBinding } from "~/bridge/protocol";

import {
  chordKey,
  findConflicts,
  foldRuns,
  groupByCategory,
  missingDesktop,
  runSummary,
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
    ["yabai -m space --focus 3", "Desktops"],
    ["yabai -m window --space 2 && yabai -m space --focus 2", "Desktops"],
    ["macarchy space 3", "Desktops"],
    [
      '"$HOME/Library/Application Support/Macarchy/Macarchy.app/Contents/Resources/skhd/scripts/move-window-to-space.sh" 2',
      "Desktops",
    ],
    ["yabai -m space --rotate 90 && yabai -m space --balance", "Windows"],
    ["'/opt/homebrew/bin/yabai' -m window --focus west", "Windows"],
    [
      '"$HOME/Library/Application Support/Macarchy/Macarchy.app/Contents/MacOS/macarchy" theme next',
      "Macarchy",
    ],
    ["macarchy bar toggle", "Macarchy"],
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
      command: "yabai -m window --ratio rel:0.1 && echo grown",
    });
    const shrink = binding({
      id: 2,
      section: "Grow and shrink",
      command: "yabai -m window --ratio rel:-0.05",
    });
    expect(shortcutTitle(grow, [grow, shrink])).toEqual({
      title: "Grow and shrink",
      command: "yabai -m window --ratio rel:0.1 && echo grown",
    });
    const left = binding({ command: "yabai -m window --focus west" });
    expect(shortcutTitle(left, [left, shrink])).toEqual({ title: "Focus left", command: null });
    const bare = binding({ command: "echo bare" });
    expect(shortcutTitle(bare, [bare])).toEqual({ title: "echo bare", command: "echo bare" });
  });
});

/** The bundled skhdrc's numbered desktop bindings, from `firstId`. */
function numbered(firstId: number, modifiers: string[], command: (n: number) => string) {
  return Array.from({ length: 9 }, (_, index) =>
    binding({
      id: firstId + index,
      modifiers,
      key: String(index + 1),
      caps: [...modifiers.map((m) => ({ ctrl: "⌃", alt: "⌥", shift: "⇧" })[m]!), `${index + 1}`],
      section: "Desktops",
      command: command(index + 1),
    }),
  );
}
const go = numbered(10, ["ctrl", "alt"], (n) => `yabai -m space --focus ${n}`);
const follow = numbered(
  20,
  ["ctrl", "alt", "shift"],
  (n) => `yabai -m window --space ${n} && yabai -m space --focus ${n}`,
);

describe("numbered runs", () => {
  it("folds each run into one item where its first binding was", () => {
    const left = binding({ id: 1, command: "yabai -m window --focus west" });
    const items = foldRuns([left, ...go, ...follow]);
    expect(items.map((item) => item.kind)).toEqual(["binding", "run", "run"]);
    const [, goRun, followRun] = items;
    expect(goRun).toMatchObject({ kind: "run", numbers: [1, 2, 3, 4, 5, 6, 7, 8, 9] });
    expect(followRun).toMatchObject({ kind: "run", bindings: follow });
  });

  it("names a run by its range and shows the keys once", () => {
    const all = [...go, ...follow];
    const [goRun, followRun] = foldRuns(all);
    if (goRun?.kind !== "run" || followRun?.kind !== "run") throw new Error("expected runs");
    expect(runSummary(goRun, all)).toEqual({
      title: "Go to desktop 1–9",
      caps: ["⌃", "⌥", "1…9"],
    });
    expect(runSummary(followRun, all)).toEqual({
      title: "Move window to desktop 1–9 and follow",
      caps: ["⌃", "⌥", "⇧", "1…9"],
    });
  });

  it("lists a broken run's numbers and sorts by key", () => {
    const some = [go[4]!, go[0]!, go[1]!];
    const [run] = foldRuns(some);
    if (run?.kind !== "run") throw new Error("expected a run");
    expect(run.numbers).toEqual([1, 2, 5]);
    expect(runSummary(run, some)).toEqual({
      title: "Go to desktop 1, 2, 5",
      caps: ["⌃", "⌥", "1,2,5"],
    });
  });

  it("keeps bindings apart unless the modifiers and command differ only by the number", () => {
    const otherModifiers = binding({ ...go[1]!, id: 40, modifiers: ["cmd"] });
    const otherCommand = binding({ id: 41, key: "3", command: "yabai -m space --focus 3; echo" });
    const notTheKey = binding({ id: 42, key: "4", command: "yabai -m space --focus 5" });
    const fraction = binding({ id: 43, key: "0", command: "yabai -m window --ratio rel:0.05" });
    const items = foldRuns([go[0]!, otherModifiers, otherCommand, notTheKey, fraction]);
    expect(items.every((item) => item.kind === "binding")).toBe(true);
    expect(foldRuns([go[0]!])).toEqual([{ kind: "binding", binding: go[0] }]);
  });

  it("leaves disabled bindings and other skhd modes out of a run", () => {
    const off = binding({ ...go[2]!, disabled: true });
    const resize = go.slice(3, 5).map((item) => binding({ ...item, modes: ["resize"] }));
    const items = foldRuns([...go.slice(0, 2), off, ...resize]);
    expect(items.map((item) => item.kind)).toEqual(["run", "binding", "run"]);
    expect(items[0]).toMatchObject({ kind: "run", numbers: [1, 2] });
    expect(items[2]).toMatchObject({ kind: "run", numbers: [4, 5] });
  });
});

describe("missing desktops", () => {
  it("marks bindings for desktops past the count, and nothing while it is unknown", () => {
    expect(go.map((item) => missingDesktop(item, 3))).toEqual([null, null, null, 4, 5, 6, 7, 8, 9]);
    expect(missingDesktop(follow[3]!, 3)).toBe(4);
    expect(missingDesktop(follow[3]!, 4)).toBeNull();
    expect(go.some((item) => missingDesktop(item, null) !== null)).toBe(false);
    expect(missingDesktop(binding({ command: "yabai -m space --focus next" }), 1)).toBeNull();
    const fullPath = binding({ command: "'/opt/homebrew/bin/yabai' -m space --focus 4" });
    expect(missingDesktop(fullPath, 3)).toBe(4);
    expect(missingDesktop(binding({ command: "macarchy space 10" }), 9)).toBe(10);
    const script = binding({
      command:
        '"$HOME/Library/Application Support/Macarchy/Macarchy.app/Contents/Resources/skhd/scripts/move-window-to-space.sh" 5',
    });
    expect(missingDesktop(script, 4)).toBe(5);
    expect(missingDesktop(script, 5)).toBeNull();
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
