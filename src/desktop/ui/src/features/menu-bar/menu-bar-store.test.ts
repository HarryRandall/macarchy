import { describe, expect, it, vi } from "vitest";

import type { BridgeEvent, MenuBarState, ThemeDetail, ThemesState } from "~/bridge/protocol";

import { barLook, createMenuBarStore, fallbackLook } from "./menu-bar-store";

const ignore: Changed = () => {};

function theme(name: string, borderActive: string | null): ThemeDetail {
  return {
    summary: {
      name,
      title: name.toUpperCase(),
      isDark: true,
      ring: "#3399ff",
      colours: {
        background: "#101010",
        foreground: "#f0f0f0",
        red: "#ff0000",
        green: "#00ff00",
        blue: "#0000ff",
        cyan: "#00ffff",
      },
      currentBackground: null,
      preview: `macarchy-app://media/${name}.jpg`,
      backgrounds: [],
    },
    values: {
      dark: true,
      borderActive,
      borderInactive: null,
      sketchybarBar: null,
      sketchybarText: null,
      firefoxAccent: null,
      nvimColorscheme: null,
    },
    modified: false,
    hasDefault: true,
    defaultColourscheme: "gruvbox",
    terminal: null,
  };
}

function state(current: string | null): ThemesState {
  return {
    themes: [theme("lumon", "#f2fcff"), theme("midnight", null)],
    current,
    colourschemes: [],
    warnings: [],
  };
}

type Changed = (event: Extract<BridgeEvent, { type: "themes.changed" }>) => void;

describe("barLook", () => {
  it("paints the bar in the applied theme", () => {
    expect(barLook(state("lumon"))).toEqual({
      background: "#101010",
      foreground: "#f0f0f0",
      accent: "#f2fcff",
      wallpaper: "macarchy-app://media/lumon.jpg",
      themeTitle: "LUMON",
    });
  });

  it("falls back to the theme's ring without a border colour", () => {
    expect(barLook(state("midnight"))?.accent).toBe("#3399ff");
  });

  it("has nothing to show without an applied theme", () => {
    expect(barLook(state(null))).toBeNull();
  });
});

const bar: MenuBarState = {
  items: [],
  bar: { height: 35, position: "top", padding: 10, centre: false },
  widgets: [],
  widgetProblems: [],
  unavailableReason: null,
};

const reads = {
  getState: () => Promise.resolve(bar),
  apply: () => Promise.resolve(bar),
  reveal: () => Promise.resolve(null),
  openFile: () => Promise.resolve(null),
  duplicate: () => Promise.resolve({ state: bar, widget: "clock-copy" }),
};

describe("createMenuBarStore", () => {
  it("is ready even when the themes cannot be read", async () => {
    const store = createMenuBarStore({
      ...reads,
      getThemes: vi.fn<() => Promise<ThemesState>>().mockRejectedValue(new Error("offline")),
      subscribe: () => () => {},
    });
    await store.load();
    expect(store.getSnapshot()).toMatchObject({ status: "ready", look: null, state: bar });
    expect(fallbackLook.themeTitle).toBe("Matte Black");
  });

  it("fails when the bar cannot be read, saying why", async () => {
    const store = createMenuBarStore({
      getThemes: () => Promise.resolve(state("lumon")),
      ...reads,
      getState: () => Promise.reject(new Error("sketchybar crashed")),
      subscribe: () => () => {},
    });
    await store.load();
    expect(store.getSnapshot()).toMatchObject({
      status: "failed",
      state: null,
      error: "sketchybar crashed",
    });
  });

  it("keeps the bar it had when an apply fails, with the reason", async () => {
    const applied = { ...bar, bar: { ...bar.bar, height: 30 } };
    const apply = vi
      .fn<() => Promise<MenuBarState>>()
      .mockResolvedValueOnce(applied)
      .mockRejectedValueOnce(new Error("Desktop is busy"));
    const store = createMenuBarStore({
      ...reads,
      apply,
      getThemes: () => Promise.resolve(state("lumon")),
      subscribe: () => () => {},
    });
    await store.load();
    expect(await store.apply([], applied.bar)).toBe(true);
    expect(store.getSnapshot().state).toBe(applied);
    expect(await store.apply([], bar.bar)).toBe(false);
    expect(store.getSnapshot()).toMatchObject({ state: applied, error: "Desktop is busy" });
    store.dismissError();
    expect(store.getSnapshot().error).toBeNull();
  });

  it("reads again when the theme changes, keeping the last look on failure", async () => {
    let changed: Changed = ignore;
    const getThemes = vi
      .fn<() => Promise<ThemesState>>()
      .mockResolvedValueOnce(state("lumon"))
      .mockResolvedValueOnce(state("midnight"))
      .mockRejectedValueOnce(new Error("busy"));
    const store = createMenuBarStore({
      ...reads,
      getThemes,
      subscribe: (_type, handler) => {
        changed = handler;
        return () => {};
      },
    });

    await store.load();
    expect(store.getSnapshot().look?.themeTitle).toBe("LUMON");

    changed({ type: "themes.changed", state: { themes: [], current: "midnight" } });
    await vi.waitFor(() => expect(store.getSnapshot().look?.themeTitle).toBe("MIDNIGHT"));

    changed({ type: "themes.changed", state: { themes: [], current: "midnight" } });
    await vi.waitFor(() => expect(getThemes).toHaveBeenCalledTimes(3));
    expect(store.getSnapshot().look?.themeTitle).toBe("MIDNIGHT");
  });

  it("takes the new widget list from a duplicate, and shows a failed file request", async () => {
    const copied = { ...bar, widgets: [] };
    const store = createMenuBarStore({
      ...reads,
      duplicate: () => Promise.resolve({ state: copied, widget: "clock-copy" }),
      reveal: () => Promise.reject(new Error("No such folder")),
      getThemes: () => Promise.resolve(state("lumon")),
      subscribe: () => () => {},
    });
    await store.load();
    expect(await store.duplicate("clock")).toBe("clock-copy");
    expect(store.getSnapshot().state).toBe(copied);
    await store.reveal("clock");
    expect(store.getSnapshot().error).toBe("No such folder");
  });
});
