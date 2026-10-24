import type { ShortcutBinding } from "~/bridge/protocol";

import { shortcutLabel } from "./shortcut-presentation";

export type ShortcutCategory = "Windows" | "Workspaces" | "Macarchy" | "Apps" | "Other";

export const categoryOrder: readonly ShortcutCategory[] = [
  "Windows",
  "Workspaces",
  "Macarchy",
  "Apps",
  "Other",
];

/**
 * The tab a binding is listed under, read from what its command does. skhdrc
 * comments give each block a name but no wider grouping, so the design's
 * tabs are inferred.
 */
export function shortcutCategory(binding: ShortcutBinding): ShortcutCategory {
  const command = binding.command;
  if (/yabai -m (space\b|window --space\b|display\b)/.test(command)) return "Workspaces";
  if (/yabai -m window\b/.test(command)) return "Windows";
  if (/\bmacarchy"?\s/i.test(command)) return "Macarchy";
  if (binding.appOverrides.length || /\b(open|osascript)\b/.test(command)) return "Apps";
  return "Other";
}

export function groupByCategory(bindings: readonly ShortcutBinding[]) {
  return categoryOrder
    .map((category) => ({
      category,
      bindings: bindings.filter((binding) => shortcutCategory(binding) === category),
    }))
    .filter((group) => group.bindings.length > 0);
}

/**
 * A row's name and, when the name is not the command, nothing under it. A
 * command Macarchy cannot name is shown under its skhdrc comment instead of
 * as the title, so rows read as actions.
 */
export function shortcutTitle(
  binding: ShortcutBinding,
  all: readonly ShortcutBinding[],
): { title: string; command: string | null } {
  const label = shortcutLabel(binding, [...all]);
  if (label === binding.command && binding.section)
    return { title: binding.section, command: binding.command };
  return { title: label, command: label === binding.command ? binding.command : null };
}

const modifierAliases: Record<string, readonly string[]> = {
  lcmd: ["cmd"],
  rcmd: ["cmd"],
  lalt: ["alt"],
  ralt: ["alt"],
  lshift: ["shift"],
  rshift: ["shift"],
  lctrl: ["ctrl"],
  rctrl: ["ctrl"],
  hyper: ["cmd", "alt", "shift", "ctrl"],
  meh: ["ctrl", "alt", "shift"],
};

/**
 * One string per physical chord, so bindings that skhd would treat as the
 * same keys compare equal. Left and right modifiers count as the same key,
 * since a person pressing either gets both bindings.
 */
export function chordKey(modifiers: readonly string[], key: string): string {
  const expanded = modifiers.flatMap((modifier) => modifierAliases[modifier] ?? [modifier]);
  return [...new Set(expanded)].toSorted().concat(key.toLowerCase()).join("+");
}

/** Chords macOS keeps for itself, so a binding on them never fires. */
const systemChords: Record<string, string> = {
  [chordKey(["cmd"], "space")]: "Spotlight",
  [chordKey(["ctrl"], "space")]: "input source switching",
  [chordKey(["cmd"], "tab")]: "the App Switcher",
};

/** Why each clashing binding cannot work, by its id. */
export function findConflicts(bindings: readonly ShortcutBinding[]): Map<number, string> {
  const conflicts = new Map<number, string>();
  const byChord = new Map<string, ShortcutBinding[]>();
  for (const binding of bindings) {
    const chord = chordKey(binding.modifiers, binding.key);
    byChord.set(chord, [...(byChord.get(chord) ?? []), binding]);
  }
  for (const binding of bindings) {
    const chord = chordKey(binding.modifiers, binding.key);
    const system = systemChords[chord];
    const other = byChord.get(chord)?.find((item) => item.id !== binding.id);
    if (system) conflicts.set(binding.id, `macOS uses ${binding.caps.join(" ")} for ${system}`);
    else if (other)
      conflicts.set(binding.id, `Same keys as "${shortcutTitle(other, bindings).title}"`);
  }
  return conflicts;
}

/** A binding on its own, or a numbered run of them shown as one row. */
export type ShortcutItem =
  | { kind: "binding"; binding: ShortcutBinding }
  | { kind: "run"; bindings: ShortcutBinding[]; numbers: number[] };

/** The digit as a whole number in a command, not part of "rel:0.05" or "f1". */
const digitPattern = (digit: string) => new RegExp(`(?<![\\w.])${digit}(?![\\w.])`, "g");

/**
 * What the bindings of one run share: the same modifiers and the same command
 * once the number is taken out. Only a digit key whose number appears in the
 * command can be part of a run.
 */
function runShape(binding: ShortcutBinding): string | null {
  if (!/^[0-9]$/.test(binding.key) || binding.appOverrides.length) return null;
  const template = binding.command.replace(digitPattern(binding.key), "#");
  if (template === binding.command) return null;
  return [chordKey(binding.modifiers, "#"), binding.passthrough, template].join("\n");
}

/**
 * Folds numbered runs, such as "Go to desktop 1" to 9, into one item each,
 * listed where the run's first binding was. A lone binding stays as it is.
 */
export function foldRuns(bindings: readonly ShortcutBinding[]): ShortcutItem[] {
  const runs = new Map<string, ShortcutBinding[]>();
  for (const binding of bindings) {
    const shape = runShape(binding);
    if (shape) runs.set(shape, [...(runs.get(shape) ?? []), binding]);
  }
  const items: ShortcutItem[] = [];
  const placed = new Set<string>();
  for (const binding of bindings) {
    const shape = runShape(binding);
    const run = shape ? runs.get(shape)! : [];
    if (run.length < 2) items.push({ kind: "binding", binding });
    else if (!placed.has(shape!)) {
      placed.add(shape!);
      const sorted = run.toSorted((a, b) => Number(a.key) - Number(b.key));
      items.push({
        kind: "run",
        bindings: sorted,
        numbers: sorted.map((item) => Number(item.key)),
      });
    }
  }
  return items;
}

function consecutive(numbers: readonly number[]) {
  return numbers.every((number, index) => index === 0 || number === numbers[index - 1]! + 1);
}

/** "1–9" for an unbroken run, otherwise "1, 2, 5". */
export function runRange(numbers: readonly number[], joiner = "–"): string {
  return consecutive(numbers) ? `${numbers[0]}${joiner}${numbers.at(-1)}` : numbers.join(", ");
}

/** The run's name and keys: "Go to desktop 1–9" on ⌃ ⌥ 1…9. */
export function runSummary(
  run: Extract<ShortcutItem, { kind: "run" }>,
  all: readonly ShortcutBinding[],
): { title: string; caps: string[] } {
  const [first] = run.bindings;
  const range = runRange(run.numbers);
  const { title } = shortcutTitle(first!, all);
  const numbered = title.replace(digitPattern(first!.key), range);
  return {
    title: numbered === title ? `${title} ${range}` : numbered,
    caps: [
      ...first!.caps.slice(0, -1),
      consecutive(run.numbers) ? runRange(run.numbers, "…") : run.numbers.join(","),
    ],
  };
}

/**
 * The desktop a binding goes to or sends a window to, when that desktop does
 * not exist yet. Nothing is marked while the count is unknown.
 */
export function missingDesktop(binding: ShortcutBinding, desktops: number | null): number | null {
  if (desktops === null) return null;
  const targets = [
    ...binding.command.matchAll(/yabai -m (?:space --focus|window --space) (\d+)(?![\w.])/g),
  ].map((match) => Number(match[1]));
  return targets.find((target) => target > desktops) ?? null;
}
