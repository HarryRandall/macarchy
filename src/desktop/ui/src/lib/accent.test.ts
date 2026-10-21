import { describe, expect, it } from "vitest";

import {
  accentVariables,
  contrastRatio,
  inkOn,
  parseHex,
  relativeLuminance,
  strokeOn,
} from "./accent";

const hex = (value: string) => {
  const rgb = parseHex(value);
  if (!rgb) throw new Error(`not a colour: ${value}`);
  return rgb;
};

describe("parseHex", () => {
  it("reads six and three digit forms in either case", () => {
    expect(parseHex("#0A84ff")).toEqual([10, 132, 255]);
    expect(parseHex("#fa0")).toEqual([255, 170, 0]);
  });

  it("rejects anything else", () => {
    expect(parseHex("0a84ff")).toBeNull();
    expect(parseHex("#12345")).toBeNull();
    expect(parseHex("rgb(0 0 0)")).toBeNull();
  });
});

describe("luminance and contrast", () => {
  it("matches the WCAG end points", () => {
    expect(relativeLuminance(hex("#000000"))).toBe(0);
    expect(relativeLuminance(hex("#ffffff"))).toBeCloseTo(1);
    expect(contrastRatio(hex("#000000"), hex("#ffffff"))).toBeCloseTo(21);
    expect(contrastRatio(hex("#777777"), hex("#777777"))).toBe(1);
  });

  it("is symmetric and matches a known pair", () => {
    // #767676 on white is the classic 4.54:1 grey.
    expect(contrastRatio(hex("#767676"), hex("#ffffff"))).toBeCloseTo(4.54, 2);
    expect(contrastRatio(hex("#ffffff"), hex("#767676"))).toBeCloseTo(4.54, 2);
  });
});

describe("inkOn", () => {
  it("keeps white on the system blue, as macOS does", () => {
    expect(inkOn(hex("#0a84ff"))).toEqual([255, 255, 255]);
    expect(inkOn(hex("#007aff"))).toEqual([255, 255, 255]);
  });

  it("uses black on a near-white accent such as Lumon's", () => {
    expect(inkOn(hex("#f2f2ee"))).toEqual([0, 0, 0]);
  });
});

describe("strokeOn", () => {
  const lightPage = [hex("#f2f2f4"), hex("#ffffff")];
  const darkPage = [hex("#1c1c1e"), hex("#2a2a2c")];

  it("leaves an accent that already stands out unchanged", () => {
    expect(strokeOn(hex("#0a84ff"), darkPage)).toEqual(hex("#0a84ff"));
  });

  it("darkens a near-white accent on light surfaces until it reaches 3:1", () => {
    const stroke = strokeOn(hex("#f2f2ee"), lightPage);
    for (const surface of lightPage)
      expect(contrastRatio(stroke, surface)).toBeGreaterThanOrEqual(3);
    expect(relativeLuminance(stroke)).toBeLessThan(relativeLuminance(hex("#f2f2ee")));
  });

  it("lightens a dark accent on dark surfaces until it reaches 3:1", () => {
    const stroke = strokeOn(hex("#1e1e5a"), darkPage);
    for (const surface of darkPage)
      expect(contrastRatio(stroke, surface)).toBeGreaterThanOrEqual(3);
    expect(relativeLuminance(stroke)).toBeGreaterThan(relativeLuminance(hex("#1e1e5a")));
  });
});

describe("accentVariables", () => {
  it("keeps the accent itself and derives ink and strokes around it", () => {
    const variables = accentVariables("#F2F2EE");
    expect(variables["--accent"]).toBe("#f2f2ee");
    expect(variables["--accent-fg"]).toBe("#000000");
    // Near white reads on the dark page as it is, but not on the light one.
    expect(variables["--accent-stroke-dark"]).toBe("#f2f2ee");
    expect(variables["--accent-stroke-light"]).not.toBe("#f2f2ee");
  });

  it("sets only the accent when it cannot be read", () => {
    expect(accentVariables("teal")).toEqual({ "--accent": "teal" });
  });
});
