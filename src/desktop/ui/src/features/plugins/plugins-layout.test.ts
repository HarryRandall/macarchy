import { describe, expect, it } from "vitest";

import { authorHue, bento, matchesQuery, pluginLayout, viewCounts } from "./plugins-layout";
import { featuredPlugins, plugins } from "./plugins-mock";

const span = { normal: 1, wide: 2, tall: 2, full: 3 } as const;

describe("bento", () => {
  it.each([1, 2, 4, 5, 6, 7, 8])("fills every row of three for %i cards", (count) => {
    const shapes = bento(count);
    expect(shapes).toHaveLength(count);
    const cells = shapes.reduce((sum, shape) => sum + span[shape], 0);
    expect(cells % 3).toBe(0);
  });

  it("stands three cards as one tall beside two", () => {
    expect(bento(3)).toEqual(["tall", "normal", "normal"]);
  });

  it("draws nothing for an empty group", () => {
    expect(bento(0)).toEqual([]);
  });
});

describe("pluginLayout", () => {
  it("features two plugins and leaves them out of their categories while unfiltered", () => {
    const layout = pluginLayout(plugins, featuredPlugins, "All", "");
    expect(layout.featured.map((plugin) => plugin.id)).toEqual(["media", "stack"]);
    const grouped = layout.groups.flatMap((group) => group.items.map((plugin) => plugin.id));
    expect(grouped).not.toContain("media");
    expect(grouped).not.toContain("stack");
    expect(layout.total).toBe(plugins.length);
  });

  it("drops the featured pair while searching so every match sits in its category", () => {
    const layout = pluginLayout(plugins, featuredPlugins, "All", "  PLAYING ");
    expect(layout.featured).toEqual([]);
    expect(layout.groups).toHaveLength(1);
    expect(layout.groups[0]?.items.map((plugin) => plugin.id)).toEqual(["media"]);
    expect(layout.groups[0]?.shapes).toEqual(["full"]);
  });

  it("shows one category with no featured row when a tab is chosen", () => {
    const layout = pluginLayout(plugins, featuredPlugins, "Windows", "");
    expect(layout.featured).toEqual([]);
    expect(layout.groups.map((group) => group.category)).toEqual(["Windows"]);
    expect(layout.groups[0]?.items.map((plugin) => plugin.id)).toEqual([
      "stack",
      "keys",
      "scratch",
    ]);
  });

  it("matches authors as well as names and reports no results", () => {
    expect(
      matchesQuery(
        plugins.find((plugin) => plugin.id === "brew")!,
        "oskar",
      ),
    ).toBe(true);
    expect(pluginLayout(plugins, featuredPlugins, "All", "zzz").total).toBe(0);
  });
});

it("counts every view for the tabs", () => {
  const counts = viewCounts(plugins);
  expect(counts.All).toBe(plugins.length);
  expect(counts["Menu bar"] + counts.Windows + counts.Integrations + counts.Focus).toBe(
    plugins.length,
  );
});

it("gives an author the same avatar hue with or without the @", () => {
  expect(authorHue("@mira")).toBe(authorHue("mira"));
  expect(authorHue("mira")).toBeGreaterThanOrEqual(0);
  expect(authorHue("mira")).toBeLessThan(360);
});
