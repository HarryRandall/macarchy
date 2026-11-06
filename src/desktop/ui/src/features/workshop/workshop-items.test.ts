import { describe, expect, it, vi } from "vitest";

import type { ThemeDetail } from "~/bridge/protocol";

import {
  appliedOnDesktop,
  buildCatalogue,
  formatCount,
  matchesQuery,
  prettyWallpaper,
  readInstalled,
  seededDownloads,
  siblingsOf,
  stepIndex,
  writeInstalled,
} from "./workshop-items";
import { communityThemes, layoutDesigns } from "./workshop-mock";

function theme(name: string, backgrounds: string[], current: string | null = null): ThemeDetail {
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
      currentBackground: current,
      preview: `macarchy-app://media/${name}.jpg`,
      backgrounds: backgrounds.map((path) => ({
        path,
        name: path.toUpperCase(),
        thumbnail: `macarchy-app://thumb/${name}/${path}`,
      })),
    },
    values: {
      dark: true,
      borderActive: "#f2fcff",
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

function present<T>(value: T | undefined): T {
  if (value === undefined) throw new Error("expected a catalogue entry");
  return value;
}

describe("formatCount", () => {
  it.each([
    [950, "950"],
    [1234, "1.2k"],
    [38_400, "38k"],
  ])("writes %i as %s", (count, text) => {
    expect(formatCount(count)).toBe(text);
  });
});

describe("prettyWallpaper", () => {
  it.each([
    ["1-the-backwater.jpg", "The backwater"],
    ["01-cherry-blossom-bokeh.webp", "Cherry blossom bokeh"],
    ["bg3.jpg", "Nord No. 3"],
    ["wall.png", "Nord classic"],
  ])("reads %s as %s", (file, name) => {
    expect(prettyWallpaper(file, "Nord")).toBe(name);
  });
});

describe("seededDownloads", () => {
  it("is stable for an id and stays inside its range", () => {
    expect(seededDownloads("nord", 100, 50)).toBe(seededDownloads("nord", 100, 50));
    expect(seededDownloads("nord", 100, 50)).toBeGreaterThanOrEqual(100);
    expect(seededDownloads("nord", 100, 50)).toBeLessThan(150);
  });
});

describe("buildCatalogue", () => {
  it("shows the placeholder catalogue with nothing installed", () => {
    const catalogue = buildCatalogue([]);
    expect(catalogue.byKind.theme).toHaveLength(communityThemes.length);
    expect(catalogue.byKind.layout).toHaveLength(layoutDesigns.length);
    expect(catalogue.all.some((item) => item.local)).toBe(false);
    expect(catalogue.featured?.id).toBe("theme:tokyo-night");
  });

  it("puts an installed theme in place of its community entry, with its own wallpapers", () => {
    const catalogue = buildCatalogue([theme("nord", ["a.jpg", "b.jpg"], "b.jpg")]);
    const nord = catalogue.byKind.theme.filter((item) => item.id === "theme:nord");
    expect(nord).toHaveLength(1);
    expect(nord[0]).toMatchObject({ name: "NORD", author: "On this Mac", local: true });
    expect(nord[0]?.images).toEqual([
      "macarchy-app://thumb/nord/b.jpg",
      "macarchy-app://thumb/nord/a.jpg",
    ]);

    const walls = catalogue.byKind.wallpaper.filter((item) => item.group === "theme:nord");
    expect(walls.map((item) => item.id)).toEqual(["wallpaper:nord/b.jpg", "wallpaper:nord/a.jpg"]);
    expect(walls.every((item) => item.local)).toBe(true);
  });

  it("adds installed themes the community does not have", () => {
    const catalogue = buildCatalogue([theme("lumon", [])]);
    const lumon = catalogue.byKind.theme.at(-1);
    expect(lumon).toMatchObject({ id: "theme:lumon", images: ["macarchy-app://media/lumon.jpg"] });
    expect(lumon?.subtitle).toBe("0 wallpapers, pairs with gruvbox in Neovim.");
  });

  it("leaves community pictures empty, since the window cannot load remote images", () => {
    const gruvbox = buildCatalogue([]).byKind.theme.find((item) => item.id === "theme:gruvbox");
    expect(gruvbox?.images).toEqual([undefined, undefined, undefined]);
  });
});

describe("matchesQuery", () => {
  const hairline = present(buildCatalogue([]).byKind.bar[0]);

  it("matches name, author, kind and tags, ignoring case and spaces", () => {
    expect(matchesQuery(hairline, "  HAIR ")).toBe(true);
    expect(matchesQuery(hairline, "macarchy")).toBe(true);
    expect(matchesQuery(hairline, "bar")).toBe(true);
    expect(matchesQuery(hairline, "minimal")).toBe(true);
    expect(matchesQuery(hairline, "")).toBe(true);
    expect(matchesQuery(hairline, "wallpaper")).toBe(false);
  });
});

describe("siblingsOf", () => {
  it("pages a wallpaper through its theme's backgrounds, and nothing else", () => {
    const catalogue = buildCatalogue([]);
    const wall = present(catalogue.byKind.wallpaper.find((item) => item.group === "theme:nord"));
    expect(siblingsOf(catalogue.all, wall).map((item) => item.name)).toEqual([
      "Black moon",
      "City view",
      "Night hawks",
    ]);
    expect(siblingsOf(catalogue.all, present(catalogue.byKind.bar[0]))).toEqual([]);
  });
});

describe("stepIndex", () => {
  it("wraps at both ends", () => {
    expect(stepIndex(2, 1, 3)).toBe(0);
    expect(stepIndex(0, -1, 3)).toBe(2);
    expect(stepIndex(0, 1, 0)).toBe(0);
  });
});

describe("appliedOnDesktop", () => {
  it("is the applied theme and its wallpaper", () => {
    expect(appliedOnDesktop([theme("nord", ["a.jpg"], "a.jpg")], "nord")).toEqual({
      theme: "theme:nord",
      wallpaper: "wallpaper:nord/a.jpg",
    });
    expect(appliedOnDesktop([theme("nord", [])], "nord")).toEqual({ theme: "theme:nord" });
    expect(appliedOnDesktop([theme("nord", [])], null)).toEqual({});
  });
});

describe("installed list storage", () => {
  it("round-trips through storage", () => {
    const values = new Map<string, string>();
    const storage = {
      getItem: (key: string) => values.get(key) ?? null,
      setItem: (key: string, value: string) => void values.set(key, value),
    };
    writeInstalled(storage, ["theme:nord"]);
    expect(readInstalled(storage)).toEqual(["theme:nord"]);
  });

  it("falls back to nothing when storage is missing, refused or holds something else", () => {
    expect(readInstalled(undefined)).toEqual([]);
    expect(readInstalled({ getItem: () => "{not json" })).toEqual([]);
    expect(readInstalled({ getItem: () => '{"theme": 1}' })).toEqual([]);
    expect(readInstalled({ getItem: () => '["theme:nord", 4]' })).toEqual(["theme:nord"]);
    const refused = vi.fn<(key: string) => string | null>(() => {
      throw new Error("SecurityError");
    });
    expect(readInstalled({ getItem: refused })).toEqual([]);
    expect(() =>
      writeInstalled(
        {
          setItem: () => {
            throw new Error("QuotaExceededError");
          },
        },
        ["theme:nord"],
      ),
    ).not.toThrow();
  });
});
