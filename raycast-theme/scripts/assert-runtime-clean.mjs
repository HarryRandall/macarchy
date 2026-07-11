import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const manifest = JSON.parse(readFileSync(join(scriptDirectory, "..", "package.json"), "utf8"));
const runtimeDependencies = join(homedir(), ".config", "raycast", "extensions", manifest.name, "node_modules");

if (existsSync(runtimeDependencies)) {
  console.error(`Raycast runtime dependencies were found at ${runtimeDependencies}.`);
  console.error("Run the Macarchy Raycast installer again before starting development.");
  process.exit(1);
}
