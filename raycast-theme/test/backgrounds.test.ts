import assert from "node:assert/strict";
import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, test } from "node:test";
import { loadBackgrounds } from "../src/backgrounds.ts";

const directories: string[] = [];

after(async () => {
  await Promise.all(directories.map((directory) => rm(directory, { force: true, recursive: true })));
});

async function themeDirectory(): Promise<string> {
  const directory = await mkdtemp(join(tmpdir(), "macarchy-backgrounds-"));
  directories.push(directory);
  return directory;
}

test("loads root and nested background images", async () => {
  const directory = await themeDirectory();
  await mkdir(join(directory, "backgrounds"));
  await writeFile(join(directory, "backgrounds", "01-city-night.jpg"), "nested image");
  await writeFile(join(directory, "sunrise.png"), "root image");

  const backgrounds = await loadBackgrounds(directory);

  assert.deepEqual(
    backgrounds.map(({ name, relativePath }) => ({ name, relativePath })),
    [
      { name: "City Night", relativePath: "backgrounds/01-city-night.jpg" },
      { name: "Sunrise", relativePath: "sunrise.png" },
    ],
  );
});

test("hides an identical root compatibility copy", async () => {
  const directory = await themeDirectory();
  await mkdir(join(directory, "backgrounds"));
  await writeFile(join(directory, "backgrounds", "01-original.jpg"), "same image");
  await writeFile(join(directory, "wall.jpg"), "same image");

  const backgrounds = await loadBackgrounds(directory);

  assert.deepEqual(
    backgrounds.map(({ relativePath }) => relativePath),
    ["backgrounds/01-original.jpg"],
  );
});

test("keeps distinct images with the same file size", async () => {
  const directory = await themeDirectory();
  await mkdir(join(directory, "backgrounds"));
  await writeFile(join(directory, "backgrounds", "nested.jpg"), "first");
  await writeFile(join(directory, "root.jpg"), "other");

  const backgrounds = await loadBackgrounds(directory);

  assert.deepEqual(
    backgrounds.map(({ relativePath }) => relativePath),
    ["backgrounds/nested.jpg", "root.jpg"],
  );
});
