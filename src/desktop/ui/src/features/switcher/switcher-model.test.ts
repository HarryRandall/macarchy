import { describe, expect, it } from "vitest";

import type { Background, SwitcherState, ThemeSummary } from "~/bridge/protocol";

import {
  actionItems,
  backgroundName,
  buildRows,
  initialModel,
  primaryAction,
  primaryTitle,
  rowKey,
  type SwitcherAction,
  type SwitcherModel,
  switcherReducer,
  visibleTiles,
} from "./switcher-model";

function backgrounds(...names: string[]): Background[] {
  return names.map((name) => ({
    path: `backgrounds/${name}.png`,
    name: backgroundName(name),
    thumbnail: "",
  }));
}

function theme(name: string, bgs: Background[] = [], current: string | null = null): ThemeSummary {
  return {
    name,
    title: name
      .split("-")
      .map((part) => part[0]?.toUpperCase() + part.slice(1))
      .join(" "),
    isDark: true,
    ring: "#000000",
    colours: null,
    currentBackground: current,
    preview: null,
    backgrounds: bgs,
  };
}

const data: SwitcherState = {
  current: "carbonfox",
  themes: [
    theme("blackgold"),
    theme(
      "carbonfox",
      backgrounds("1-ember", "2-fox-den", "3-night", "4-dawn", "5-dusk"),
      "backgrounds/3-night.png",
    ),
    theme("city-783"),
    theme("lumon", backgrounds("1-refinement")),
    theme("awakening"),
  ],
};

function run(model: SwitcherModel, ...actions: SwitcherAction[]) {
  return actions.reduce(switcherReducer, model);
}

const keys = (model: SwitcherModel) => buildRows(model.data, model.ui.search).map(rowKey);

describe("rows", () => {
  it("puts Switch Background first, then awakening and lumon, then by name", () => {
    expect(buildRows(data, "").map(rowKey)).toEqual([
      "backgrounds",
      "theme:awakening",
      "theme:lumon",
      "theme:blackgold",
      "theme:carbonfox",
      "theme:city-783",
    ]);
  });

  it("filters titles case-insensitively and keeps Switch Background only when it matches", () => {
    expect(buildRows(data, "CITY").map(rowKey)).toEqual(["theme:city-783"]);
    expect(buildRows(data, "B").map(rowKey)).toEqual([
      "backgrounds",
      "theme:blackgold",
      "theme:carbonfox",
    ]);
    expect(buildRows(data, "fox").map(rowKey)).toEqual(["theme:carbonfox"]);
    expect(buildRows(data, "zzz")).toEqual([]);
  });

  it("has no Switch Background row without themes", () => {
    expect(buildRows({ themes: [], current: null }, "")).toEqual([]);
  });
});

describe("selection", () => {
  it("starts on the current theme", () => {
    expect(initialModel(data).ui).toMatchObject({
      search: "",
      mode: { kind: "themes" },
      selection: "theme:carbonfox",
      actionsOpen: false,
    });
  });

  it("starts on the first row when nothing is applied", () => {
    expect(initialModel({ ...data, current: null }).ui.selection).toBe("backgrounds");
  });

  it("moves by one and stops at the ends", () => {
    let model = initialModel(data);
    model = run(model, { type: "step", delta: 1 });
    expect(model.ui.selection).toBe("theme:city-783");
    model = run(model, { type: "step", delta: 1 }, { type: "step", delta: 1 });
    expect(model.ui.selection).toBe("theme:city-783");
    model = run(model, ...Array.from({ length: 10 }, () => ({ type: "step", delta: -1 }) as const));
    expect(model.ui.selection).toBe("backgrounds");
  });

  it("keeps the selection while it stays visible and otherwise takes the first row", () => {
    let model = initialModel(data);
    model = run(model, { type: "search", search: "fox" });
    expect(model.ui.selection).toBe("theme:carbonfox");
    model = run(model, { type: "search", search: "lu" });
    expect(model.ui.selection).toBe("theme:lumon");
    expect(keys(model)).toEqual(["theme:lumon"]);
  });

  it("keeps the selection when themes change, if it is still there", () => {
    let model = run(initialModel(data), { type: "select", key: "theme:lumon" });
    model = run(model, { type: "data", data: { ...data, current: "lumon" } });
    expect(model.ui.selection).toBe("theme:lumon");
    model = run(model, {
      type: "data",
      data: { ...data, themes: data.themes.filter((entry) => entry.name !== "lumon") },
    });
    expect(model.ui.selection).toBe("backgrounds");
  });

  it("resets everything when the panel opens", () => {
    let model = run(
      initialModel(data),
      { type: "search", search: "x" },
      { type: "toggleActions" },
      { type: "openBackgrounds", theme: "carbonfox" },
    );
    model = run(model, { type: "reset", data: { ...data, current: "lumon" } });
    expect(model.ui).toEqual({
      search: "",
      mode: { kind: "themes" },
      selection: "theme:lumon",
      tile: null,
      actionsOpen: false,
      action: 0,
    });
  });
});

const grid = () => run(initialModel(data), { type: "openBackgrounds", theme: "carbonfox" });

describe("background grid", () => {
  it("lists the current background first and selects it", () => {
    const model = grid();
    expect(visibleTiles(model).map((bg) => bg.name)).toEqual([
      "Night",
      "Ember",
      "Fox Den",
      "Dawn",
      "Dusk",
    ]);
    expect(model.ui.tile).toBe("backgrounds/3-night.png");
    expect(model.ui.search).toBe("");
  });

  it("moves by a row with Up and Down and by one with Left and Right, clamped", () => {
    let model = run(grid(), { type: "step", delta: 1 });
    expect(model.ui.tile).toBe("backgrounds/2-fox-den.png");
    model = run(model, { type: "gridStep", delta: 1 });
    expect(model.ui.tile).toBe("backgrounds/4-dawn.png");
    model = run(model, { type: "step", delta: 1 }, { type: "step", delta: 1 });
    expect(model.ui.tile).toBe("backgrounds/5-dusk.png");
    model = run(model, { type: "step", delta: -1 });
    expect(model.ui.tile).toBe("backgrounds/2-fox-den.png");
    model = run(model, { type: "gridStep", delta: -1 }, { type: "gridStep", delta: -1 });
    expect(model.ui.tile).toBe("backgrounds/3-night.png");
  });

  it("ignores Left and Right in the theme list", () => {
    const model = initialModel(data);
    expect(run(model, { type: "gridStep", delta: 1 })).toBe(model);
  });

  it("filters by name and keeps the selection only while visible", () => {
    let model = run(grid(), { type: "search", search: "d" });
    expect(visibleTiles(model).map((bg) => bg.name)).toEqual(["Fox Den", "Dawn", "Dusk"]);
    expect(model.ui.tile).toBe("backgrounds/2-fox-den.png");
    model = run(model, { type: "gridStep", delta: 1 }, { type: "search", search: "da" });
    expect(model.ui.tile).toBe("backgrounds/4-dawn.png");
  });

  it("returns to the theme list with the search cleared", () => {
    const model = run(grid(), { type: "search", search: "d" }, { type: "showThemes" });
    expect(model.ui).toMatchObject({ mode: { kind: "themes" }, search: "", tile: null });
    expect(model.ui.selection).toBe("theme:carbonfox");
  });

  it("falls back to the theme list when its theme disappears", () => {
    const model = run(grid(), {
      type: "data",
      data: { ...data, themes: data.themes.filter((entry) => entry.name !== "carbonfox") },
    });
    expect(model.ui.mode).toEqual({ kind: "themes" });
  });
});

describe("primary action", () => {
  it("applies the selected theme", () => {
    const model = run(initialModel(data), { type: "select", key: "theme:lumon" });
    expect(primaryAction(model)).toEqual({ kind: "apply", theme: "lumon" });
    expect(primaryTitle(model)).toBe("Apply Theme");
  });

  it("opens the active theme's backgrounds from the Switch Background row", () => {
    const model = run(initialModel(data), { type: "select", key: "backgrounds" });
    expect(primaryAction(model)).toEqual({ kind: "openBackgrounds", theme: "carbonfox" });
    expect(primaryTitle(model)).toBe("Open Backgrounds");
  });

  it("uses the selected tile in the grid", () => {
    const model = run(initialModel(data), { type: "openBackgrounds", theme: "lumon" });
    expect(primaryAction(model)).toEqual({
      kind: "useBackground",
      theme: "lumon",
      path: "backgrounds/1-refinement.png",
    });
    expect(primaryTitle(model)).toBe("Use Background");
  });

  it("has nothing to do with no selection", () => {
    const empty = initialModel({ themes: [], current: null });
    expect(primaryAction(empty)).toBeNull();
  });
});

describe("actions menu", () => {
  it("offers Switch Background only for a theme row in theme mode", () => {
    const onTheme = initialModel(data);
    expect(actionItems(onTheme).map((item) => item.title)).toEqual([
      "Apply Theme",
      "Switch Background",
      "Refresh Themes",
      "Open Macarchy",
    ]);
    const onRow = run(onTheme, { type: "select", key: "backgrounds" });
    expect(actionItems(onRow).map((item) => item.command)).toEqual([
      "primary",
      "refresh",
      "openSettings",
    ]);
  });

  it("takes Up and Down while open and leaves the list selection alone", () => {
    let model = run(initialModel(data), { type: "toggleActions" });
    model = run(model, { type: "step", delta: 1 }, { type: "step", delta: 1 });
    expect(model.ui.action).toBe(2);
    expect(model.ui.selection).toBe("theme:carbonfox");
    model = run(model, ...Array.from({ length: 5 }, () => ({ type: "step", delta: 1 }) as const));
    expect(model.ui.action).toBe(3);
    model = run(model, { type: "closeActions" }, { type: "toggleActions" });
    expect(model.ui.action).toBe(0);
  });
});

describe("null fields from the host", () => {
  // The host sends absent optionals as JSON null, never leaves them out.
  const bare = theme("lumon", backgrounds("1-refinement"));
  const state: SwitcherState = { current: null, themes: [bare, theme("awakening")] };

  it("never builds a row key from a null current theme", () => {
    const model = initialModel(state);
    expect(model.ui.selection).toBe("backgrounds");
    expect(keys(model)).not.toContain("theme:null");
    expect(run(model, { type: "step", delta: 1 }).ui.selection).toBe("theme:awakening");
  });

  it("falls back to the host's first theme for Switch Background, as the SwiftUI did", () => {
    const model = run(initialModel(state), { type: "select", key: "backgrounds" });
    expect(primaryAction(model)).toEqual({ kind: "openBackgrounds", theme: "lumon" });
  });

  it("lists backgrounds of a theme with no current background, colours or preview", () => {
    expect(bare).toMatchObject({ colours: null, currentBackground: null, preview: null });
    const model = run(initialModel(state), { type: "openBackgrounds", theme: "lumon" });
    expect(visibleTiles(model).map((bg) => bg.path)).toEqual(["backgrounds/1-refinement.png"]);
    expect(model.ui.tile).toBe("backgrounds/1-refinement.png");
  });

  it("resets to the first row when the applied theme becomes null", () => {
    const model = run(initialModel(data), { type: "reset", data: { ...data, current: null } });
    expect(model.ui.selection).toBe("backgrounds");
  });
});

describe("backgroundName", () => {
  it("drops the ordering prefix and extension and capitalises words", () => {
    expect(backgroundName("backgrounds/2-hand-of-adam.png")).toBe("Hand Of Adam");
    expect(backgroundName("wallpaper_dark.jpg")).toBe("Wallpaper Dark");
  });
});
