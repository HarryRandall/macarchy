import { describe, expect, it } from "vitest";

import { clampNumber, parseNumberDraft, stepNumber } from "./number";

describe("clampNumber", () => {
  it("pins values inside the bounds", () => {
    expect(clampNumber(-4, { min: 0, max: 10 })).toBe(0);
    expect(clampNumber(14, { min: 0, max: 10 })).toBe(10);
  });

  it("rounds to the requested places", () => {
    expect(clampNumber(0.456, { min: 0, max: 1, decimals: 2 })).toBe(0.46);
    expect(clampNumber(3.6, { min: 0, max: 10 })).toBe(4);
  });
});

describe("parseNumberDraft", () => {
  const bounds = { min: 0, max: 100 };

  it("snaps back on blank or unparseable text", () => {
    expect(parseNumberDraft("", bounds)).toBeNull();
    expect(parseNumberDraft("   ", bounds)).toBeNull();
    expect(parseNumberDraft("ten", bounds)).toBeNull();
    expect(parseNumberDraft("Infinity", bounds)).toBeNull();
  });

  it("commits a typed number, clamped", () => {
    expect(parseNumberDraft(" 42 ", bounds)).toBe(42);
    expect(parseNumberDraft("250", bounds)).toBe(100);
  });
});

describe("stepNumber", () => {
  it("moves one step and stops at the ends", () => {
    expect(stepNumber(4, 1, 1, { min: 0, max: 5 })).toBe(5);
    expect(stepNumber(5, 1, 1, { min: 0, max: 5 })).toBe(5);
    expect(stepNumber(0, -1, 1, { min: 0, max: 5 })).toBe(0);
  });

  it("lands back on the step grid from an off-grid value", () => {
    expect(stepNumber(7, 1, 5, { min: 0, max: 50 })).toBe(10);
    expect(stepNumber(0.3, 1, 0.25, { min: 0, max: 1, decimals: 2 })).toBe(0.5);
  });
});
