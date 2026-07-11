import { homedir } from "node:os";
import { join } from "node:path";

export const DEFAULT_PATHS = {
  themeStateDirectory: "~/.local/state/macarchy/themes",
  themeSwitcherPath: "~/.local/bin/theme-switch",
  themesDirectory: "~/.config/themes",
} as const;

export function expandHome(value: string, homeDirectory = homedir()): string {
  const path = value.trim();

  if (path === "~" || path === "$HOME") return homeDirectory;
  if (path.startsWith("~/")) return join(homeDirectory, path.slice(2));
  if (path.startsWith("$HOME/")) return join(homeDirectory, path.slice(6));
  return path;
}

export function resolvePreferencePath(value: unknown, fallback: string, homeDirectory = homedir()): string {
  const configuredPath = typeof value === "string" ? value.trim() : "";
  return expandHome(configuredPath || fallback, homeDirectory);
}
