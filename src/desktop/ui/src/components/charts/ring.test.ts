import { describe, expect, it } from "vitest";

import { ringGeometry, ringWeight } from "./ring";

describe("ringGeometry", () => {
  it("splits the ring into equal arcs less the gaps", () => {
    const ring = ringGeometry(4, 40, 4, 3);
    expect(ring.centre).toBe(20);
    expect(ring.radius).toBe(18);
    expect(ring.arc).toBeCloseTo(ring.circumference / 4 - 3);
    expect(ring.angles).toHaveLength(4);
    expect(ring.angles[1]! - ring.angles[0]!).toBeCloseTo(90);
  });

  it("starts each arc half a gap past its slot so gaps sit between arcs", () => {
    const ring = ringGeometry(2, 40, 4, 3);
    expect(ring.angles[0]).toBeCloseTo((1.5 / ring.circumference) * 360);
  });

  it("draws a single arc as a closed ring", () => {
    const ring = ringGeometry(1, 16, 3, 1.75);
    expect(ring.arc).toBeCloseTo(ring.circumference);
    expect(ring.angles).toEqual([0]);
  });

  it("draws nothing when there are no segments", () => {
    expect(ringGeometry(0, 16, 3, 1.75).angles).toEqual([]);
  });
});

describe("ringWeight", () => {
  it("is thinner at bar size", () => {
    expect(ringWeight(16)).toEqual({ stroke: 3, gap: 1.75 });
    expect(ringWeight(40)).toEqual({ stroke: 4, gap: 3 });
  });
});
