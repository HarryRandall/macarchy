import { describe, expect, it } from "vitest";

import { goBack, goForward, startHistory, visit } from "./history";

describe("history", () => {
  it("steps back and forward through visited routes", () => {
    let history = visit(visit(startHistory("home"), "themes"), "rules");
    history = goBack(history);
    expect(history.current).toBe("themes");
    history = goBack(history);
    expect(history.current).toBe("home");
    expect(history.past).toEqual([]);
    history = goForward(history);
    expect(history.current).toBe("themes");
    expect(history.future).toEqual(["rules"]);
  });

  it("drops the forward routes when going somewhere new", () => {
    const history = visit(goBack(visit(startHistory("home"), "themes")), "layout");
    expect(history.past).toEqual(["home"]);
    expect(history.current).toBe("layout");
    expect(history.future).toEqual([]);
  });

  it("ignores a visit to the route already shown", () => {
    const history = visit(startHistory("home"), "themes");
    expect(visit(history, "themes")).toBe(history);
  });

  it("stays put at either end", () => {
    const history = startHistory("home");
    expect(goBack(history)).toBe(history);
    expect(goForward(history)).toBe(history);
  });

  it("keeps the fifty most recent routes behind the current one", () => {
    let history = startHistory(0);
    for (let route = 1; route <= 60; route++) history = visit(history, route);
    expect(history.past).toHaveLength(50);
    expect(history.past[0]).toBe(10);
    expect(history.current).toBe(60);
  });
});
