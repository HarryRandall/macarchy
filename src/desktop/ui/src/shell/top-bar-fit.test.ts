import { describe, expect, it } from "vitest";

import { topBarFit } from "./top-bar-fit";

describe("topBarFit", () => {
  it("shows everything in a wide window", () => {
    expect(topBarFit(900, 0)).toEqual({
      group: true,
      searchField: true,
      logsLabel: true,
      padding: 32,
    });
  });

  it("drops the breadcrumb's group first", () => {
    const fit = topBarFit(500, 0);
    expect(fit.group).toBe(false);
    expect(fit.searchField).toBe(true);
  });

  it("collapses search and Logs to icons beside the sidebar at the smallest window", () => {
    // A 720 px window with the sidebar open leaves the bar about 448 px.
    const fit = topBarFit(448, 180);
    expect(fit).toEqual({ group: false, searchField: false, logsLabel: false, padding: 16 });
  });

  it("gives up room sooner when a page has more actions", () => {
    expect(topBarFit(700, 0).group).toBe(true);
    expect(topBarFit(700, 200).group).toBe(false);
  });
});
