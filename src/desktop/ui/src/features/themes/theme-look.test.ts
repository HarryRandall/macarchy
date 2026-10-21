import { describe, expect, it } from "vitest";
import type { ThemeDetail } from "~/bridge/protocol";
import {
  nextWallpaper,
  stepTheme,
  themeLook,
  wallpaperImage,
  wallpaperName,
  wallpaperPosition,
} from "./theme-look";

const backgrounds = [
  { path: "backgrounds/0-ship.png", name: "Ship", thumbnail: "thumb:ship" },
  { path: "backgrounds/bg2.png", name: "Bg2", thumbnail: "thumb:bg2" },
  { path: "backgrounds/wall.png", name: "Wall", thumbnail: "thumb:wall" },
];

function detail(patch: Partial<ThemeDetail> = {}): ThemeDetail {
  return {
    summary: {
      name: "matte-black",
      title: "Matte Black",
      isDark: true,
      ring: "#3399ff",
      colours: {
        background: "#121212",
        foreground: "#bebebe",
        red: "#d35f5f",
        green: "#ffc107",
        blue: "#e68e0d",
        cyan: "#bebebe",
      },
      currentBackground: "backgrounds/bg2.png",
      preview: "preview:bg2",
      backgrounds,
    },
    values: {
      dark: true,
      borderActive: "0xffe68e0d",
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
    ...patch,
  };
}

describe("themeLook", () => {
  it("reads the accent from the active border and the wallpaper in force", () => {
    const look = themeLook(detail());
    expect(look.accent).toBe("#e68e0d");
    expect(look.background).toBe("#121212");
    expect(look.nvim).toBe("gruvbox");
    expect(look.wallpaper?.path).toBe("backgrounds/bg2.png");
    expect(look.palette).toHaveLength(8);
  });

  it("prefers the Ghostty palette and falls back to the ring without a border colour", () => {
    const ansi = Array.from({ length: 16 }, (_, index) => `#0000${String(index).padStart(2, "0")}`);
    const look = themeLook(
      detail({
        terminal: { background: "#000000", foreground: "#ffffff", cursor: "#ffffff", ansi },
        values: { ...detail().values, borderActive: null, nvimColorscheme: "lumon" },
      }),
    );
    expect(look.palette).toEqual(ansi.slice(0, 8));
    expect(look.background).toBe("#000000");
    expect(look.accent).toBe("#3399ff");
    expect(look.nvim).toBe("lumon");
  });

  it("uses the first wallpaper when none is recorded and none at all when the theme has none", () => {
    const base = detail();
    expect(
      themeLook(detail({ summary: { ...base.summary, currentBackground: null } })).wallpaper?.path,
    ).toBe("backgrounds/0-ship.png");
    expect(themeLook(detail({ summary: { ...base.summary, backgrounds: [] } })).wallpaper).toBe(
      null,
    );
  });
});

describe("wallpapers", () => {
  const look = themeLook(detail());

  it("names bare file names by position", () => {
    expect(wallpaperName(look, backgrounds[0]!)).toBe("Ship");
    expect(wallpaperName(look, backgrounds[1]!)).toBe("Wallpaper 2");
    expect(wallpaperName(look, backgrounds[2]!)).toBe("Wallpaper 3");
  });

  it("steps to the next wallpaper, wrapping round, and reports the position", () => {
    expect(nextWallpaper(look)?.path).toBe("backgrounds/wall.png");
    expect(wallpaperPosition(look)).toBe("2/3");
    const last = { ...look, wallpaper: backgrounds[2]! };
    expect(nextWallpaper(last)?.path).toBe("backgrounds/0-ship.png");
    expect(nextWallpaper({ ...look, wallpapers: [backgrounds[0]!] })).toBe(null);
  });

  it("shows the large preview only for the wallpaper in force", () => {
    expect(wallpaperImage(look, backgrounds[1]!, "preview:bg2")).toBe("preview:bg2");
    expect(wallpaperImage(look, backgrounds[0]!, "preview:bg2")).toBe("thumb:ship");
    expect(wallpaperImage(look, null, "preview:bg2")).toBe("preview:bg2");
  });
});

describe("stepTheme", () => {
  it("wraps in both directions", () => {
    expect(stepTheme(["a", "b", "c"], 0, -1)).toBe("c");
    expect(stepTheme(["a", "b", "c"], 2, 1)).toBe("a");
    expect(stepTheme([], 0, 1)).toBe(undefined);
  });
});
