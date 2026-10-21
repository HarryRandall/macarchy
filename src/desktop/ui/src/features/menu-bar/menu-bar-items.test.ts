import { describe, expect, it } from "vitest";

import {
  addItem,
  hiddenInCentre,
  matchesLibrary,
  moveItem,
  patchItem,
  removeItem,
  sameItems,
  shiftZone,
  stepItem,
  zonesFor,
} from "./menu-bar-items";
import { type BarItem, library, type Zone } from "./menu-bar-mock";

function item(id: string, zone: Zone): BarItem {
  return { id, label: id, zone, on: true, sample: "", icon: "AppWindow" };
}

const bar = [item("a", "left"), item("b", "left"), item("c", "right"), item("d", "right")];
const order = (items: BarItem[]) => items.map((entry) => `${entry.zone}:${entry.id}`);

describe("moveItem", () => {
  it("puts an item before another, taking its zone", () => {
    expect(order(moveItem(bar, "a", "right", "d"))).toEqual([
      "left:b",
      "right:c",
      "right:a",
      "right:d",
    ]);
  });

  it("appends to the zone without a target", () => {
    expect(order(moveItem(bar, "c", "left"))).toEqual(["left:a", "left:b", "left:c", "right:d"]);
  });

  it("appends to an empty zone at the end", () => {
    expect(order(moveItem(bar, "a", "centre"))).toEqual([
      "left:b",
      "right:c",
      "right:d",
      "centre:a",
    ]);
  });

  it("ignores dropping an item on itself or an unknown id", () => {
    expect(moveItem(bar, "a", "left", "a")).toBe(bar);
    expect(moveItem(bar, "x", "left")).toBe(bar);
  });
});

describe("stepItem", () => {
  it("moves within the zone in either direction", () => {
    expect(order(stepItem(bar, "b", -1)).slice(0, 2)).toEqual(["left:b", "left:a"]);
    expect(order(stepItem(bar, "c", 1)).slice(2)).toEqual(["right:d", "right:c"]);
  });

  it("stops at the zone's ends", () => {
    expect(stepItem(bar, "a", -1)).toBe(bar);
    expect(stepItem(bar, "b", 1)).toBe(bar);
  });
});

describe("shiftZone", () => {
  it("moves to the neighbouring zone, skipping a hidden centre", () => {
    expect(order(shiftZone(bar, "b", 1, zonesFor(false)))).toContain("right:b");
    expect(order(shiftZone(bar, "b", 1, zonesFor(true)))).toContain("centre:b");
  });

  it("stops at the outer zones", () => {
    expect(shiftZone(bar, "a", -1, zonesFor(true))).toBe(bar);
    expect(shiftZone(bar, "d", 1, zonesFor(true))).toBe(bar);
  });
});

describe("addItem, removeItem and patchItem", () => {
  it("adds after the zone's last item", () => {
    expect(order(addItem(bar, item("e", "left")))).toEqual([
      "left:a",
      "left:b",
      "left:e",
      "right:c",
      "right:d",
    ]);
  });

  it("removes and patches by id", () => {
    expect(order(removeItem(bar, "c"))).toEqual(["left:a", "left:b", "right:d"]);
    expect(patchItem(bar, "a", { on: false })[0]?.on).toBe(false);
    expect(patchItem(bar, "a", { on: false })[1]).toBe(bar[1]);
  });
});

describe("hiddenInCentre", () => {
  it("counts centre items only while the centre zone is off", () => {
    const withCentre = [...bar, item("e", "centre")];
    expect(hiddenInCentre(withCentre, false)).toBe(1);
    expect(hiddenInCentre(withCentre, true)).toBe(0);
  });
});

const names = (query: string) =>
  library.filter((entry) => matchesLibrary(entry, query)).map((entry) => entry.name);

describe("matchesLibrary", () => {
  it("searches the name, detail and category", () => {
    expect(names("bolt")).toEqual(["Battery"]);
    expect(names("MEDIA")).toEqual(["Now playing"]);
    expect(names("  ")).toHaveLength(library.length);
  });
});

describe("sameItems", () => {
  it("treats an edit put back by hand as no change", () => {
    const edited = patchItem(bar, "a", { label: "Changed" });
    expect(sameItems(bar, edited)).toBe(false);
    expect(sameItems(bar, patchItem(edited, "a", { label: "a" }))).toBe(true);
  });
});
