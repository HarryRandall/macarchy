import { describe, expect, it } from "vitest";

import {
  addItem,
  type BarItem,
  editsOf,
  moveItem,
  newItem,
  patchItem,
  problemWith,
  removeItem,
  sameItems,
  shiftZone,
  shownText,
  stepItem,
  type Zone,
} from "./menu-bar-items";

function item(id: string, zone: Zone, kind: BarItem["kind"] = null): BarItem {
  return {
    id,
    title: id,
    zone,
    visible: true,
    kind,
    text: "",
    icon: "",
    command: null,
    interval: null,
    reading: "",
  };
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
  it("moves to the neighbouring zone", () => {
    expect(order(shiftZone(bar, "b", 1))).toContain("centre:b");
    expect(order(shiftZone(bar, "c", -1))).toContain("centre:c");
  });

  it("stops at the outer zones", () => {
    expect(shiftZone(bar, "a", -1)).toBe(bar);
    expect(shiftZone(bar, "d", 1)).toBe(bar);
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

  it("removes made items only, and patches by id", () => {
    const made = [...bar, item("macarchy.e", "right", "text")];
    expect(order(removeItem(made, "macarchy.e"))).toEqual(order(bar));
    expect(removeItem(bar, "c")).toEqual(bar);
    expect(patchItem(bar, "a", { visible: false })[0]?.visible).toBe(false);
    expect(patchItem(bar, "a", { visible: false })[1]).toBe(bar[1]);
  });
});

describe("newItem", () => {
  it("makes a SketchyBar-safe id and the kind's defaults", () => {
    const made = newItem("command", "centre");
    expect(made.id).toMatch(/^macarchy\.[a-z0-9-]+$/);
    expect(made).toMatchObject({ zone: "centre", kind: "command", command: "", interval: 30 });
    expect(newItem("text", "left").text).toBe("Hello");
  });
});

describe("problemWith and shownText", () => {
  it("needs a name, and a command for a command item", () => {
    expect(problemWith(item("a", "left"))).toBeNull();
    expect(problemWith({ ...item("a", "left"), title: " " })).toMatch(/name/);
    expect(problemWith(newItem("command", "left"))).toMatch(/command/);
  });

  it("shows a text item's text and a waiting command", () => {
    expect(shownText({ ...item("t", "left", "text"), text: "Hi" })).toBe("Hi");
    expect(shownText(item("c", "left", "command"))).toBe("…");
    expect(shownText({ ...item("cpu", "right"), reading: "12%" })).toBe("12%");
  });
});

describe("sameItems", () => {
  it("treats an edit put back by hand as no change", () => {
    const edited = patchItem(bar, "a", { title: "Changed" });
    expect(sameItems(bar, edited)).toBe(false);
    expect(sameItems(bar, patchItem(edited, "a", { title: "a" }))).toBe(true);
  });

  it("ignores readings, which the page never edits", () => {
    expect(sameItems(bar, patchItem(bar, "a", { reading: "12%" }))).toBe(true);
    expect(editsOf(bar)[0]).not.toHaveProperty("reading");
  });
});
