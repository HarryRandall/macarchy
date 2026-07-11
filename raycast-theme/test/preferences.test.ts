import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { DEFAULT_PATHS, resolvePreferencePath } from "../src/paths.ts";
import { normaliseLegacyThemeName } from "../src/theme-utils.ts";

const HOME = "/Users/example";

test("keeps manifest defaults aligned with runtime defaults", async () => {
  const manifest = JSON.parse(await readFile(new URL("../package.json", import.meta.url), "utf8")) as {
    preferences: Array<{ default?: string; name: keyof typeof DEFAULT_PATHS }>;
  };

  for (const preference of manifest.preferences) {
    assert.equal(preference.default, DEFAULT_PATHS[preference.name]);
  }
});

test("uses portable defaults when preferences are unset or empty", () => {
  assert.equal(resolvePreferencePath(undefined, DEFAULT_PATHS.themesDirectory, HOME), "/Users/example/.config/themes");
  assert.equal(
    resolvePreferencePath("   ", DEFAULT_PATHS.themeStateDirectory, HOME),
    "/Users/example/.local/state/macarchy/themes",
  );
  assert.equal(
    resolvePreferencePath(null, DEFAULT_PATHS.themeSwitcherPath, HOME),
    "/Users/example/.local/bin/theme-switch",
  );
});

test("trims configured paths and expands home references", () => {
  assert.equal(resolvePreferencePath("  ~/themes  ", DEFAULT_PATHS.themesDirectory, HOME), "/Users/example/themes");
  assert.equal(
    resolvePreferencePath(" $HOME/bin/theme-switch ", DEFAULT_PATHS.themeSwitcherPath, HOME),
    "/Users/example/bin/theme-switch",
  );
  assert.equal(resolvePreferencePath(" /Volumes/Themes ", DEFAULT_PATHS.themesDirectory, HOME), "/Volumes/Themes");
});

test("keeps an original theme active while its pack is installed", () => {
  assert.equal(normaliseLegacyThemeName("lumon\n", [{ name: "lumon" }, { name: "cool-blue" }]), "lumon");
  assert.equal(normaliseLegacyThemeName("turbonite", [{ name: "turbonite" }, { name: "amber-metal" }]), "turbonite");
});

test("uses a renamed theme only when the original pack is absent", () => {
  assert.equal(normaliseLegacyThemeName("lumon", [{ name: "cool-blue" }]), "cool-blue");
  assert.equal(normaliseLegacyThemeName("turbonite", [{ name: "amber-metal" }]), "amber-metal");
  assert.equal(normaliseLegacyThemeName("custom", [{ name: "cool-blue" }]), "custom");
});
