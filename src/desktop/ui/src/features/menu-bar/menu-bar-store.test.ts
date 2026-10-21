import { describe, expect, it, vi } from "vitest";

import type { BridgeEvent, ThemeDetail, ThemesState } from "~/bridge/protocol";

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

describe("createMenuBarStore", () => {
  it("is ready even when the themes cannot be read", async () => {
    const store = createMenuBarStore({
      getThemes: vi.fn<() => Promise<ThemesState>>().mockRejectedValue(new Error("offline")),
      subscribe: () => () => {},
    });
    await store.load();
    expect(store.getSnapshot()).toEqual({ status: "ready", look: null });
    expect(fallbackLook.themeTitle).toBe("Matte Black");
  });

  it("reads again when the theme changes, keeping the last look on failure", async () => {
    let changed: Changed = ignore;
    const getThemes = vi
      .fn<() => Promise<ThemesState>>()
      .mockResolvedValueOnce(state("lumon"))
      .mockResolvedValueOnce(state("midnight"))
      .mockRejectedValueOnce(new Error("busy"));
    const store = createMenuBarStore({
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
});
