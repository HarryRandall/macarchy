import { describe, expect, it } from "vitest";
import type { BorderAppearance } from "~/bridge/contract/borders";
import {
  borderHex,
  borderPaint,
  bordersArguments,
  cornerPreset,
  followsTheme,
  isNoop,
  presetRadius,
  presetColours,
  previewRadius,
  themeReset,
  withHex,
} from "./borders-format";

const appearance: BorderAppearance = {
  width: 10,
  visible: true,
  excludedApps: ["iPhone Mirroring", "Messages"],
  radius: 0.3,
  activeColour: "0x80112233",
  inactiveColour: null,
};

describe("corners", () => {
  it("names the presets and leaves other radii custom", () => {
    expect(cornerPreset(null)).toBe("system");
    expect(cornerPreset(0.3)).toBe("square");
    expect(cornerPreset(8)).toBe("rounded");
    expect(cornerPreset(4.5)).toBe("custom");
    expect(presetRadius("square")).toBe(0.3);
    expect(presetRadius("system")).toBe(null);
  });

  it("previews square under 1 pt and a system radius when unset", () => {
    expect(previewRadius(0.3)).toBe(0);
    expect(previewRadius(6)).toBe(6);
    expect(previewRadius(null)).toBe(10);
  });
});

describe("bordersArguments", () => {
  it("writes the width with one decimal and the colours as saved", () => {
    expect(bordersArguments(appearance)).toEqual([
      "width=10.0",
      "hidpi=on",
      "background_color=0x00000000",
      'blacklist="iPhone Mirroring,Messages"',
      "active_color=0x80112233",
      "inactive_color=0x00000000",
    ]);
  });

  it("draws nothing when borders are hidden", () => {
    const hidden = bordersArguments({ ...appearance, visible: false });
    expect(hidden[0]).toBe("width=0.0");
    expect(hidden.at(-2)).toBe("active_color=0x00000000");
  });
});

describe("theme colours", () => {
  const defaults = { ...appearance, activeColour: "0xffe68e0d", inactiveColour: "0xff333333" };

  it("follows the theme only when both colours match its own", () => {
    expect(followsTheme(appearance, defaults)).toBe(false);
    expect(followsTheme({ ...appearance, ...themeReset(defaults) }, defaults)).toBe(true);
    expect(followsTheme(appearance, null)).toBe(false);
  });

  it("resets width and visibility even without theme defaults", () => {
    expect(themeReset(null)).toEqual({ width: 6, visible: true });
    expect(isNoop({ ...appearance, width: 6 }, themeReset(null))).toBe(true);
    expect(isNoop(appearance, themeReset(defaults))).toBe(false);
  });

  it("keeps the opacity when a preset replaces a colour", () => {
    expect(withHex("0x80112233", "#ABCDEF")).toBe("0x80abcdef");
    expect(withHex(null, "#abcdef")).toBe("0xffabcdef");
    expect(withHex("0x80112233", "nope")).toBe(null);
    expect(borderHex("0x80112233")).toBe("#112233");
    expect(borderHex(null)).toBe(null);
    expect(presetColours(["0xffe68e0d", "#E68E0D", null, "bad", "#333333"])).toEqual([
      "#e68e0d",
      "#333333",
    ]);
  });

  it("paints unset colours with the fallback", () => {
    expect(borderPaint(null, "transparent")).toBe("transparent");
    expect(borderPaint("0xff112233", "transparent")).toBe("rgb(17 34 51 / 1)");
  });
});
