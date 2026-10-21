import { describe, expect, it } from "vitest";

import {
  cssColour,
  formatColour,
  hsvaToRgba,
  normaliseColour,
  parseColour,
  rgbaToHsva,
} from "./colour";

describe("parseColour", () => {
  it("reads the borders and SketchyBar form with its alpha first", () => {
    expect(parseColour("0xff89b4fa")).toEqual({ a: 255, r: 0x89, g: 0xb4, b: 0xfa });
    expect(parseColour("0X8011AAff")).toEqual({ a: 0x80, r: 0x11, g: 0xaa, b: 0xff });
  });

  it("reads #rrggbb as opaque and #aarrggbb as the Swift parser does", () => {
    expect(parseColour("#0A84ff")).toEqual({ r: 10, g: 132, b: 255, a: 255 });
    expect(parseColour("#400a84ff")).toEqual({ a: 0x40, r: 10, g: 132, b: 255 });
  });

  it("trims surrounding space", () => {
    expect(parseColour("  #ffffff \n")).toEqual({ r: 255, g: 255, b: 255, a: 255 });
  });

  it("rejects anything else", () => {
    for (const value of [null, undefined, "", "#fff", "0xfff", "#12345", "0x1234567", "#gggggg"])
      expect(parseColour(value)).toBeNull();
    expect(parseColour("rgb(0 0 0)")).toBeNull();
    expect(parseColour("0x#ffffff")).not.toBeNull(); // Swift strips both prefixes too.
  });
});

describe("formatColour", () => {
  it("writes each notation in lower case", () => {
    const colour = { r: 0xab, g: 0xcd, b: 0xef, a: 0x12 };
    expect(formatColour(colour, "argb")).toBe("0x12abcdef");
    expect(formatColour(colour, "rgb")).toBe("#abcdef");
  });

  it("clamps and rounds stray channels", () => {
    expect(formatColour({ r: 300, g: -4, b: 127.6, a: 255 }, "argb")).toBe("0xffff0080");
  });

  it("round-trips every value it writes", () => {
    for (const value of ["0xff000000", "0x00ffffff", "0x7f123456", "0xffe1e2e3"])
      expect(normaliseColour(value, "argb")).toBe(value);
    for (const value of ["#000000", "#ffffff", "#0a84ff"])
      expect(normaliseColour(value, "rgb")).toBe(value);
  });

  it("converts between notations without touching the colour", () => {
    expect(normaliseColour("#0A84FF", "argb")).toBe("0xff0a84ff");
    expect(normaliseColour("0x800a84ff", "rgb")).toBe("#0a84ff");
    expect(normaliseColour("teal", "rgb")).toBeNull();
  });
});

describe("hsv", () => {
  it("places the primaries and greys", () => {
    expect(rgbaToHsva({ r: 255, g: 0, b: 0, a: 255 })).toEqual({ h: 0, s: 1, v: 1, a: 1 });
    expect(rgbaToHsva({ r: 0, g: 255, b: 0, a: 255 }).h).toBeCloseTo(1 / 3);
    expect(rgbaToHsva({ r: 0, g: 0, b: 255, a: 0 })).toMatchObject({ s: 1, v: 1, a: 0 });
    expect(rgbaToHsva({ r: 128, g: 128, b: 128, a: 255 })).toMatchObject({ h: 0, s: 0 });
    expect(rgbaToHsva({ r: 0, g: 0, b: 0, a: 255 })).toMatchObject({ s: 0, v: 0 });
  });

  it("wraps hue rather than clamping it", () => {
    expect(hsvaToRgba({ h: 1, s: 1, v: 1, a: 1 })).toEqual({ r: 255, g: 0, b: 0, a: 255 });
    expect(hsvaToRgba({ h: -1 / 3, s: 1, v: 1, a: 1 })).toEqual({ r: 0, g: 0, b: 255, a: 255 });
  });

  it("round-trips 8-bit colours exactly", () => {
    const channels = [0, 1, 17, 64, 127, 128, 200, 254, 255];
    for (const r of channels)
      for (const g of channels)
        for (const b of channels) {
          const colour = { r, g, b, a: (r + g) % 256 };
          expect(hsvaToRgba(rgbaToHsva(colour))).toEqual(colour);
        }
  });
});

describe("cssColour", () => {
  it("paints alpha as a fraction", () => {
    expect(cssColour({ r: 1, g: 2, b: 3, a: 255 })).toBe("rgb(1 2 3 / 1)");
    expect(cssColour({ r: 1, g: 2, b: 3, a: 128 })).toBe("rgb(1 2 3 / 0.502)");
  });
});
