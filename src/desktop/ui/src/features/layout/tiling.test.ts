import { describe, expect, it } from "vitest";

import { bspRects, savedValueLines, splitHint, splitsSideBySide } from "./tiling";

describe("splitsSideBySide", () => {
  it("follows the monitor's longer edge when automatic", () => {
    expect(splitsSideBySide("auto", "landscape")).toBe(true);
    expect(splitsSideBySide("auto", "portrait")).toBe(false);
  });

  it("ignores the monitor for a fixed direction", () => {
    expect(splitsSideBySide("vertical", "portrait")).toBe(true);
    expect(splitsSideBySide("horizontal", "landscape")).toBe(false);
  });
});

describe("splitHint", () => {
  it("names the monitor only for an automatic split", () => {
    expect(splitHint("auto", "landscape")).toBe("Side by side on this landscape monitor");
    expect(splitHint("auto", "portrait")).toBe("Above and below on this portrait monitor");
    expect(splitHint("horizontal", "landscape")).toBe("Above and below");
  });
});

describe("bspRects", () => {
  it("gives one window the whole area", () => {
    expect(bspRects(1, true, "second_child")).toEqual([{ x: 0, y: 0, width: 1, height: 1 }]);
  });

  it("halves the newest window, alternating direction", () => {
    expect(bspRects(3, true, "second_child")).toEqual([
      { x: 0, y: 0, width: 0.5, height: 1 },
      { x: 0.5, y: 0, width: 0.5, height: 0.5 },
      { x: 0.5, y: 0.5, width: 0.5, height: 0.5 },
    ]);
  });

  it("puts newer windows left or above as the first child", () => {
    expect(bspRects(3, true, "first_child")).toEqual([
      { x: 0.5, y: 0, width: 0.5, height: 1 },
      { x: 0, y: 0.5, width: 0.5, height: 0.5 },
      { x: 0, y: 0, width: 0.5, height: 0.5 },
    ]);
  });

  it("starts above and below when the first split is horizontal", () => {
    const [first, second] = bspRects(2, false, "second_child");
    expect(first).toEqual({ x: 0, y: 0, width: 1, height: 0.5 });
    expect(second).toEqual({ x: 0, y: 0.5, width: 1, height: 0.5 });
  });

  it("covers the area exactly, whatever the count", () => {
    for (const count of [1, 2, 3, 4]) {
      const area = bspRects(count, true, "first_child").reduce(
        (sum, rect) => sum + rect.width * rect.height,
        0,
      );
      expect(area).toBeCloseTo(1);
    }
  });
});

describe("savedValueLines", () => {
  it("writes the keys settings.json uses", () => {
    const lines = savedValueLines({
      layout: "stack",
      splitType: "auto",
      windowPlacement: "first_child",
      autoBalance: true,
      windowGap: 12,
      padding: 6,
      mouseModifier: "alt",
      mouseFollowsFocus: false,
      mouseDropAction: "swap",
    });
    expect(lines).toContain(`"layout": "stack",`);
    expect(lines).toContain(`"window_placement": "first_child",`);
    expect(lines).toContain(`"top_padding": 6,`);
    expect(lines.at(-1)).toBe(`"mouse_follows_focus": false`);
  });
});
