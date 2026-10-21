import type { GeneratedFileId } from "~/bridge/protocol";

/**
 * Placeholder figures from the Studio design for what the host does not
 * report yet: file sizes over time, files per tool, when each generated file
 * was written and how it differs from what Macarchy would write. Swap each
 * for real data when the host has it. Each use is marked `Mock:`.
 */

/** Total size of the generated configuration in KB at the end of each of the last 30 days. */
export const configSizes: readonly number[] = [
  38.2, 38.2, 38.6, 38.6, 38.9, 39.4, 39.4, 39.4, 40.1, 40.3, 40.3, 41.8, 42.2, 42.4, 42.4, 42.4,
  43.6, 43.1, 43.9, 43.9, 43.9, 46.0, 46.2, 46.9, 46.9, 47.3, 48.0, 48.4, 49.6, 51.2,
];

export interface ToolFiles {
  name: string;
  files: number;
  lines: number;
  written: string;
}

/** Files Macarchy generates for each tool. */
export const toolFiles: readonly ToolFiles[] = [
  { name: "SketchyBar", files: 14, lines: 612, written: "Yesterday, 21:40" },
  { name: "yabai", files: 3, lines: 214, written: "Today, 09:31" },
  { name: "skhd", files: 2, lines: 96, written: "Today, 17:02" },
  { name: "JankyBorders", files: 1, lines: 18, written: "Today, 16:48" },
];

/** When each generated file was last written. */
export const fileWritten: Record<GeneratedFileId, string> = {
  yabairc: "Today, 17:02",
  sketchybarrc: "Yesterday, 21:40",
  bordersrc: "Today, 16:48",
};

export interface DiffLine {
  kind: " " | "+" | "-";
  text: string;
  /** The line's number in the file on disk. */
  line: number;
}

/** Edits made outside Macarchy, as a rebuild would replace them. Empty means none. */
export const fileEdits: Record<GeneratedFileId, readonly DiffLine[]> = {
  yabairc: [],
  sketchybarrc: [
    { kind: " ", text: "sketchybar --add item clock right", line: 41 },
    { kind: "-", text: "sketchybar --set clock update_freq=30", line: 42 },
    { kind: "+", text: "sketchybar --set clock update_freq=10 \\", line: 42 },
    { kind: "+", text: '  icon.font="SF Pro:Semibold:13.0"', line: 43 },
    { kind: " ", text: "", line: 44 },
    { kind: "+", text: "# Spotify now playing, added by hand", line: 45 },
    { kind: "+", text: "sketchybar --add item spotify right", line: 46 },
  ],
  bordersrc: [],
};

/** Where the command line tool would be installed. */
export const commandPath = "/opt/homebrew/bin/macarchy";
