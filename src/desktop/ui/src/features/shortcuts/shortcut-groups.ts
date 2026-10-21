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
