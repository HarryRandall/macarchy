import assert from "node:assert/strict";
import { mkdir, mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { spawnSync } from "node:child_process";
import { after, test } from "node:test";

const homes: string[] = [];
const guard = join(import.meta.dirname, "..", "scripts", "assert-runtime-clean.mjs");

after(async () => {
  await Promise.all(homes.map((home) => rm(home, { force: true, recursive: true })));
});

async function temporaryHome(): Promise<string> {
  const home = await mkdtemp(join(tmpdir(), "macarchy-raycast-"));
  homes.push(home);
  return home;
}

test("allows development when the Raycast runtime has no dependencies", async () => {
  const home = await temporaryHome();
  const result = spawnSync(process.execPath, [guard], { env: { ...process.env, HOME: home }, encoding: "utf8" });

  assert.equal(result.status, 0, result.stderr);
});

test("blocks duplicate React dependencies in the Raycast runtime", async () => {
  const home = await temporaryHome();
  const dependencies = join(home, ".config", "raycast", "extensions", "theme-switcher", "node_modules");
  await mkdir(dirname(dependencies), { recursive: true });
  await mkdir(dependencies);

  const result = spawnSync(process.execPath, [guard], { env: { ...process.env, HOME: home }, encoding: "utf8" });

  assert.equal(result.status, 1);
  assert.match(result.stderr, /Raycast runtime dependencies were found/);
});
