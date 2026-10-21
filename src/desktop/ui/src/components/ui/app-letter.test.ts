import { describe, expect, it } from "vitest";

import { appLetter, letterHue } from "./app-letter";

describe("letterHue", () => {
  it("gives the same name the same hue", () => {
    expect(letterHue("Finder")).toBe(letterHue("Finder"));
  });

  it("stays on the colour wheel", () => {
    for (const name of ["", "Finder", "TablePlus", "1Password 8", "日本語"]) {
      const hue = letterHue(name);
      expect(hue).toBeGreaterThanOrEqual(0);
      expect(hue).toBeLessThan(360);
    }
  });

  it("tells similar names apart", () => {
    expect(letterHue("Safari")).not.toBe(letterHue("Slack"));
  });
});

describe("appLetter", () => {
  it("capitalises the first character after any spaces", () => {
    expect(appLetter("  ghostty")).toBe("G");
  });

  it("keeps a character outside the basic plane whole", () => {
    expect(appLetter("🦊 Firefox")).toBe("🦊");
  });

  it("falls back to a question mark for an empty name", () => {
    expect(appLetter("   ")).toBe("?");
  });
});
