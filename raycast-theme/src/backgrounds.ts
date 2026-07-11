import { readdir, readFile, stat } from "node:fs/promises";
import { basename, extname, join } from "node:path";

export type Background = {
  aliasPaths: string[];
  name: string;
  path: string;
  relativePath: string;
};

type BackgroundCandidate = Background & {
  directory: string;
  size: number;
};

const IMAGE_EXTENSIONS = new Set([".heic", ".jpeg", ".jpg", ".png", ".webp"]);

function titleFromBackgroundName(name: string): string {
  return basename(name, extname(name))
    .replace(/^\d+[-_.\s]*/, "")
    .replace(/[-_.]+/g, " ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

async function hasSameContents(left: BackgroundCandidate, right: BackgroundCandidate): Promise<boolean> {
  if (left.size !== right.size) return false;
  const [leftContents, rightContents] = await Promise.all([readFile(left.path), readFile(right.path)]);
  return leftContents.equals(rightContents);
}

export async function loadBackgrounds(themeDirectory: string): Promise<Background[]> {
  const candidates: BackgroundCandidate[] = [];

  // A pack can keep images at its root, under backgrounds/, or in both. Read
  // the subdirectory first so an identical root-level compatibility copy does
  // not appear as a second choice.
  for (const directory of ["backgrounds", ""]) {
    let entries;
    try {
      entries = await readdir(join(themeDirectory, directory), { withFileTypes: true });
    } catch (error) {
      const code = error instanceof Error && "code" in error ? error.code : undefined;
      if (code === "ENOENT") continue;
      throw error;
    }

    for (const entry of entries) {
      if (!entry.isFile() || entry.name.startsWith(".") || !IMAGE_EXTENSIONS.has(extname(entry.name).toLowerCase())) {
        continue;
      }

      const relativePath = directory ? `${directory}/${entry.name}` : entry.name;
      const path = join(themeDirectory, relativePath);
      const details = await stat(path);
      candidates.push({
        aliasPaths: [],
        directory,
        name: titleFromBackgroundName(entry.name),
        path,
        relativePath,
        size: details.size,
      });
    }
  }

  const unique: BackgroundCandidate[] = [];
  for (const candidate of candidates) {
    let duplicate = false;
    for (const existing of unique) {
      if (candidate.directory !== existing.directory && (await hasSameContents(candidate, existing))) {
        existing.aliasPaths.push(candidate.relativePath);
        duplicate = true;
        break;
      }
    }
    if (!duplicate) unique.push(candidate);
  }

  return unique
    .map((background) => ({
      aliasPaths: background.aliasPaths,
      name: background.name,
      path: background.path,
      relativePath: background.relativePath,
    }))
    .sort((left, right) => left.relativePath.localeCompare(right.relativePath));
}

export function backgroundMatchesPath(background: Background, relativePath: string): boolean {
  return background.relativePath === relativePath || background.aliasPaths.includes(relativePath);
}
