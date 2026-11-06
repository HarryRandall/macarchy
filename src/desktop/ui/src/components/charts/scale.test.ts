import { describe, expect, it } from "vitest";

import {
  areaPath,
  barPath,
  fitDomain,
  linear,
  linePath,
  nearestIndex,
  niceStep,
  placeAbove,
  placeBeside,
  rampLevel,
  rampPercent,
  runs,
  stepIndex,
  zeroDomain,
} from "./scale";

describe("niceStep", () => {
  it("rounds up to 1, 2, 2.5 or 5 times a power of ten", () => {
    expect(niceStep(0.7)).toBe(1);
    expect(niceStep(1.4)).toBe(2);
    expect(niceStep(2.3)).toBe(2.5);
    expect(niceStep(3.1)).toBe(5);
    expect(niceStep(7)).toBe(10);
    expect(niceStep(140)).toBe(200);
    expect(niceStep(0.03)).toBe(0.05);
  });

  it("falls back to one for empty or invalid ranges", () => {
    expect(niceStep(0)).toBe(1);
    expect(niceStep(-5)).toBe(1);
    expect(niceStep(Number.NaN)).toBe(1);
  });
});

describe("zeroDomain", () => {
  it("covers the peak in even steps from zero", () => {
    expect(zeroDomain(14)).toEqual({ min: 0, max: 15, ticks: [0, 5, 10, 15] });
    expect(zeroDomain(3, 3)).toEqual({ min: 0, max: 3, ticks: [0, 1, 2, 3] });
  });

  it("keeps one step of headroom when everything is zero", () => {
    expect(zeroDomain(0)).toEqual({ min: 0, max: 1, ticks: [0, 1] });
  });

  it("labels decimal steps without float noise", () => {
    expect(zeroDomain(0.3, 3).ticks).toEqual([0, 0.1, 0.2, 0.3]);
  });
});

describe("fitDomain", () => {
  it("frames the data on round values", () => {
    expect(fitDomain(41.2, 47.9)).toEqual({ min: 40, max: 50, ticks: [40, 45, 50] });
  });

  it("opens a flat series into a visible band", () => {
    const domain = fitDomain(12, 12);
    expect(domain.min).toBeLessThanOrEqual(12);
    expect(domain.max).toBeGreaterThan(domain.min);
  });
});

describe("linear", () => {
  it("maps across the range, inverted for screen y", () => {
    const y = linear([0, 10], [100, 0]);
    expect(y(0)).toBe(100);
    expect(y(5)).toBe(50);
    expect(y(10)).toBe(0);
  });

  it("maps a flat domain to the start of the range", () => {
    expect(linear([3, 3], [0, 50])(3)).toBe(0);
  });
});

describe("nearestIndex", () => {
  it("finds the closest position", () => {
    expect(nearestIndex([0, 10, 20], 14)).toBe(1);
    expect(nearestIndex([0, 10, 20], 16)).toBe(2);
  });

  it("returns -1 with nothing to choose", () => {
    expect(nearestIndex([], 5)).toBe(-1);
  });
});

describe("paths", () => {
  it("draws a line and closes its area to the baseline", () => {
    const points = [
      { x: 0, y: 10 },
      { x: 5, y: 2 },
    ];
    expect(linePath(points)).toBe("M0,10L5,2");
    expect(areaPath(points, 20)).toBe("M0,10L5,2L5,20L0,20Z");
    expect(areaPath([], 20)).toBe("");
  });

  it("breaks a series into runs at missing values", () => {
    const result = runs([1, null, 2, 3, null], (value, index) => ({ x: index, y: value }));
    expect(result).toEqual([
      [{ x: 0, y: 1 }],
      [
        { x: 2, y: 2 },
        { x: 3, y: 3 },
      ],
    ]);
  });

  it("shrinks a bar's corner to fit a short bar and skips empty ones", () => {
    expect(barPath(0, 0, 10, 2)).toContain("A2,2");
    expect(barPath(0, 0, 10, 20)).toContain("A4,4");
    expect(barPath(0, 0, 10, 0)).toBe("");
    expect(barPath(0, 0, 10, 20, { round: false })).toContain("A0,0");
  });

  it("rounds a row's right end", () => {
    expect(barPath(0, 0, 40, 10, { direction: "right" })).toBe(
      "M0,0H36A4,4 0 0 1 40,4V6A4,4 0 0 1 36,10H0Z",
    );
  });
});

describe("placeBeside", () => {
  const bounds = { width: 200, height: 100 };
  const tip = { width: 60, height: 30 };

  it("prefers the right of the point", () => {
    expect(placeBeside({ x: 50, y: 50 }, tip, bounds)).toEqual({ left: 62, top: 35 });
  });

  it("flips left when the right would overflow", () => {
    expect(placeBeside({ x: 180, y: 50 }, tip, bounds).left).toBe(108);
  });

  it("stays inside the chart vertically", () => {
    expect(placeBeside({ x: 50, y: 2 }, tip, bounds).top).toBe(0);
    expect(placeBeside({ x: 50, y: 99 }, tip, bounds).top).toBe(70);
  });
});

describe("placeAbove", () => {
  const bounds = { width: 200, height: 100 };
  const tip = { width: 60, height: 30 };

  it("centres above the point", () => {
    expect(placeAbove({ x: 100, y: 60 }, tip, bounds)).toEqual({ left: 70, top: 22 });
  });

  it("drops below the target when there is no room above", () => {
    expect(placeAbove({ x: 100, y: 10 }, tip, bounds, { below: 20 }).top).toBe(28);
  });

  it("clamps to the chart's sides", () => {
    expect(placeAbove({ x: 5, y: 60 }, tip, bounds).left).toBe(0);
    expect(placeAbove({ x: 198, y: 60 }, tip, bounds).left).toBe(140);
  });
});

describe("stepIndex", () => {
  it("starts on the latest point by default", () => {
    expect(stepIndex(null, "ArrowLeft", 5)).toBe(4);
    expect(stepIndex(null, "ArrowDown", 5, { orientation: "vertical", start: 0 })).toBe(0);
  });

  it("moves and stops at the ends", () => {
    expect(stepIndex(2, "ArrowRight", 5)).toBe(3);
    expect(stepIndex(4, "ArrowRight", 5)).toBe(4);
    expect(stepIndex(0, "ArrowLeft", 5)).toBe(0);
  });

  it("jumps with Home and End", () => {
    expect(stepIndex(2, "Home", 5)).toBe(0);
    expect(stepIndex(2, "End", 5)).toBe(4);
  });

  it("ignores keys for the other orientation and empty charts", () => {
    expect(stepIndex(2, "ArrowUp", 5)).toBeUndefined();
    expect(stepIndex(2, "ArrowLeft", 5, { orientation: "vertical" })).toBeUndefined();
    expect(stepIndex(null, "ArrowLeft", 0)).toBeUndefined();
  });
});

describe("ramp", () => {
  it("climbs from empty through 40% to full over four levels", () => {
    expect([0, 1, 2, 3].map((level) => rampPercent(level, 4))).toEqual([0, 40, 70, 100]);
  });

  it("buckets counts relative to the busiest day", () => {
    expect(rampLevel(0, 9, 4)).toBe(0);
    expect(rampLevel(1, 9, 4)).toBe(1);
    expect(rampLevel(5, 9, 4)).toBe(2);
    expect(rampLevel(9, 9, 4)).toBe(3);
  });
});
