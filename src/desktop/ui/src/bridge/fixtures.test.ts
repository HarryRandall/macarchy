import { describe, expect, it } from "vitest";

import { eventFixtures, methodFixtures } from "./fixtures";

/** The parts of `node:fs/promises` used here; the app's project has no Node types. */
interface FileSystem {
  readFile(path: URL, encoding: "utf8"): Promise<string>;
  writeFile(path: URL, data: string): Promise<void>;
  mkdir(path: URL, options: { recursive: true }): Promise<unknown>;
}

type NodeGlobals = { process?: { env: Record<string, string | undefined> } };

const directory = new URL("../../../../../tests/fixtures/bridge/", import.meta.url);
const updating = (globalThis as NodeGlobals).process?.env.UPDATE_BRIDGE_FIXTURES === "1";

async function fileSystem(): Promise<FileSystem> {
  // Not a literal, so the app's type check does not look for Node's declarations.
  const specifier: string = "node:fs/promises";
  return (await import(/* @vite-ignore */ specifier)) as FileSystem;
}

/** Keys sorted at every level, so reordering `fixtures.ts` changes nothing on disk. */
function sorted(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(sorted);
  if (value === null || typeof value !== "object") return value;
  const record = value as Record<string, unknown>;
  const keys = Object.keys(record).toSorted();
  return Object.fromEntries(keys.map((key) => [key, sorted(record[key])]));
}

function serialise(fixtures: unknown): string {
  return `${JSON.stringify(sorted(fixtures), null, 2)}\n`;
}

describe("bridge fixtures", () => {
  it.each([
    ["methods.json", methodFixtures],
    ["events.json", eventFixtures],
  ])("tests/fixtures/bridge/%s matches fixtures.ts", async (name, fixtures) => {
    const fs = await fileSystem();
    const file = new URL(name, directory);
    const expected = serialise(fixtures);
    if (updating) {
      await fs.mkdir(directory, { recursive: true });
      await fs.writeFile(file, expected);
      return;
    }
    const committed = await fs.readFile(file, "utf8").catch(() => null);
    try {
      expect(committed).toBe(expected);
    } catch (error) {
      throw new Error(
        `tests/fixtures/bridge/${name} differs from src/bridge/fixtures.ts. If the contract ` +
          "changed on purpose, run UPDATE_BRIDGE_FIXTURES=1 corepack pnpm vitest run " +
          "src/bridge/fixtures.test.ts in src/desktop/ui, commit the JSON and run swift test.",
        { cause: error },
      );
    }
  });
});
