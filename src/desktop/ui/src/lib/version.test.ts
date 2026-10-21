import { describe, expect, it } from "vitest";

import { isNewer } from "./version";

describe("isNewer", () => {
  it.each([
    ["0.9.2", "0.9.1", true],
    ["0.10.0", "0.9.9", true],
    ["1.0", "0.99.99", true],
    ["0.9.1", "0.9.2", false],
    ["0.9.2", "0.9.2", false],
    ["1.2", "1.2.0", false],
    ["1.2.1", "1.2", true],
  ])("compares %s with %s", (a, b, expected) => {
    expect(isNewer(a, b)).toBe(expected);
  });

  it("treats parts that are not numbers as zero", () => {
    expect(isNewer("1.x", "1.0")).toBe(false);
    expect(isNewer("1.1", "1.x")).toBe(true);
  });
});
