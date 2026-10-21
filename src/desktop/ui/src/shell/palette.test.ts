import { describe, expect, it } from "vitest";

import { filterPalette, groupPalette, type PaletteItem, stepIndex } from "./palette";

const items: PaletteItem[] = [
  { id: "logs", label: "Show logs", keys: "⇧⌘L", section: "Actions" },
  { id: "themes", label: "Themes", hint: "Appearance", section: "Go to" },
  { id: "borders", label: "Borders", hint: "Appearance", section: "Go to" },
  { id: "shortcuts", label: "Shortcuts", hint: "Behaviour", section: "Go to" },
  {
    id: "folder",
    label: "Open config folder",
    hint: "~/.config/macarchy",
    section: "Actions",
    keywords: ["finder", "reveal"],
  },
  { id: "page", label: "Filter Rules", section: "This page" },
];

const ids = (list: PaletteItem[]) => list.map((item) => item.id);

describe("filterPalette", () => {
  it("lists everything by section when the query is empty", () => {
    expect(ids(filterPalette(items, "  "))).toEqual([
      "page",
      "themes",
      "borders",
      "shortcuts",
      "logs",
      "folder",
    ]);
  });

  it("matches the label, the hint and hidden keywords, ignoring case", () => {
    expect(ids(filterPalette(items, "APPEARANCE"))).toEqual(["themes", "borders"]);
    expect(ids(filterPalette(items, "finder"))).toEqual(["folder"]);
  });

  it("needs every word of the query to match", () => {
    expect(ids(filterPalette(items, "open folder"))).toEqual(["folder"]);
    expect(ids(filterPalette(items, "open themes"))).toEqual([]);
  });

  it("puts labels that start with the query first within a section", () => {
    const list: PaletteItem[] = [
      { id: "folder", label: "Open config folder", section: "Actions", keywords: ["reveal"] },
      { id: "yabai", label: "Restart yabai", section: "Actions" },
      { id: "reveal", label: "Reveal backups", section: "Actions" },
    ];
    expect(ids(filterPalette(list, "rev"))).toEqual(["reveal", "folder"]);
    expect(ids(filterPalette(list, "yab"))).toEqual(["yabai"]);
  });

  it("ranks a label with a word starting with the query above a match inside a word", () => {
    const list: PaletteItem[] = [
      { id: "borders", label: "Borders", section: "Go to" },
      { id: "order", label: "Change order", section: "Go to" },
    ];
    expect(ids(filterPalette(list, "order"))).toEqual(["order", "borders"]);
  });
});

describe("groupPalette", () => {
  it("keeps each item's index in the flat list", () => {
    const groups = groupPalette(filterPalette(items, "o"));
    expect(groups.map((group) => group.section)).toEqual(["Go to", "Actions"]);
    expect(groups[1]?.items.map(({ item, index }) => [item.id, index])).toEqual([
      ["folder", 2],
      ["logs", 3],
    ]);
  });
});

describe("stepIndex", () => {
  it("wraps at both ends", () => {
    expect(stepIndex(2, 1, 3)).toBe(0);
    expect(stepIndex(0, -1, 3)).toBe(2);
    expect(stepIndex(1, 1, 3)).toBe(2);
  });

  it("stays at zero when there is nothing to move to", () => {
    expect(stepIndex(0, 1, 0)).toBe(0);
  });
});
