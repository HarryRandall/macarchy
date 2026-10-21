import { describe, expect, it } from "vitest";

import { healthSummary } from "./health-summary";

describe("healthSummary", () => {
  it("counts failed and warning checks and reads the model", () => {
    const snapshot = {
      status: "ready",
      state: {
        checks: [
          { id: "a", status: "passed" },
          { id: "b", status: "failed" },
          { id: "c", status: "warning" },
          { id: "d", status: "unknown" },
        ],
        environment: { model: "MacBook Pro" },
      },
    };
    expect(healthSummary(snapshot)).toEqual({ issues: 2, model: "MacBook Pro" });
  });

  it("knows nothing before the checks have been read", () => {
    expect(healthSummary({ status: "loading", state: null })).toEqual({
      issues: null,
      model: null,
    });
    expect(healthSummary({ status: "loading" })).toEqual({ issues: null, model: null });
  });

  it("leaves out a missing or empty model", () => {
    expect(healthSummary({ state: { checks: [], environment: { model: "" } } })).toEqual({
      issues: 0,
      model: null,
    });
  });
});
