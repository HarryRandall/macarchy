import { describe, expect, it } from "vitest";

import { rovingIndex } from "./roving";

const all = [true, true, true, true];

describe("rovingIndex", () => {
  it("moves along the row and wraps at both ends", () => {
    expect(rovingIndex(1, "ArrowRight", all)).toBe(2);
    expect(rovingIndex(3, "ArrowRight", all)).toBe(0);
    expect(rovingIndex(0, "ArrowLeft", all)).toBe(3);
  });

  it("skips disabled items", () => {
    const some = [true, false, false, true];
    expect(rovingIndex(0, "ArrowRight", some)).toBe(3);
    expect(rovingIndex(3, "ArrowRight", some)).toBe(0);
    expect(rovingIndex(0, "ArrowLeft", some)).toBe(3);
  });

  it("jumps to the first and last enabled item", () => {
    const ends = [false, true, true, false];
    expect(rovingIndex(2, "Home", ends)).toBe(1);
    expect(rovingIndex(1, "End", ends)).toBe(2);
  });

  it("uses Up and Down for a vertical row and ignores the other axis", () => {
    expect(rovingIndex(0, "ArrowDown", all, "vertical")).toBe(1);
    expect(rovingIndex(0, "ArrowUp", all, "vertical")).toBe(3);
    expect(rovingIndex(0, "ArrowRight", all, "vertical")).toBeUndefined();
  });

  it("ignores other keys and rows with nothing enabled", () => {
    expect(rovingIndex(0, "Enter", all)).toBeUndefined();
    expect(rovingIndex(0, "ArrowRight", [false, false])).toBeUndefined();
  });
});
