import type { ShortcutBinding, ShortcutChord } from "~/bridge/protocol";

export function shortcutLabel(binding: ShortcutBinding, all: ShortcutBinding[]): string {
  if (binding.section && all.filter((item) => item.section === binding.section).length === 1)
    return binding.section;
  const command = binding.command;
  for (const [native, title] of [
    ["west", "left"],
    ["east", "right"],
    ["north", "up"],
    ["south", "down"],
  ]) {
    if (command === `yabai -m window --focus ${native}`) return `Focus ${title}`;
    if (command === `yabai -m window --swap ${native}; yabai -m window --focus ${native}`)
      return `Swap ${title} and follow`;
  }
  for (let index = 1; index <= 20; index++) {
    if (command === `yabai -m space --focus ${index}`) return `Switch to workspace ${index}`;
    if (command === `yabai -m window --space ${index}`) return `Move to workspace ${index}`;
    if (command === `yabai -m window --space ${index}; yabai -m space --focus ${index}`)
      return `Move to workspace ${index} and follow`;
  }
  for (const [action, title] of [
    ["playpause", "Play or pause Spotify"],
    ["next track", "Next track in Spotify"],
    ["previous track", "Previous track in Spotify"],
  ]) {
    if (
      command ===
      `/usr/bin/pgrep -x Spotify >/dev/null && /usr/bin/osascript -e 'tell application "Spotify" to ${action}'`
    )
      return title!;
  }
  return command || (binding.appOverrides.length ? "Per-app action" : "Custom shortcut");
}

export interface ShortcutFilters {
  search: string;
  modifiers: string[];
  scope: "all" | "global" | "perApp";
  section: string;
}
export const emptyFilters: ShortcutFilters = {
  search: "",
  modifiers: [],
  scope: "all",
  section: "",
};
export function filterBindings(all: ShortcutBinding[], filters: ShortcutFilters) {
  const query = filters.search.trim().toLowerCase();
  return all.filter(
    (binding) =>
      (filters.scope === "all" || (filters.scope === "perApp") === !!binding.appOverrides.length) &&
      (!filters.section || binding.section === filters.section) &&
      filters.modifiers.every((wanted) =>
        binding.modifiers.some((value) => value.endsWith(wanted)),
      ) &&
      (!query ||
        [
          shortcutLabel(binding, all),
          binding.command,
          binding.caps.join(" "),
          binding.section ?? "",
          binding.key,
        ].some((value) => value.toLowerCase().includes(query))),
  );
}

/** The physical key, independent of Shift and Option's transformed characters. Swift validates it. */
export function recordedChord(
  event: Pick<
    KeyboardEvent,
    "code" | "metaKey" | "altKey" | "ctrlKey" | "shiftKey" | "isComposing" | "repeat"
  >,
): ShortcutChord | null {
  if (event.isComposing || event.repeat) return null;
  const special: Record<string, string> = {
    Enter: "return",
    Tab: "tab",
    Space: "space",
    Backspace: "delete",
    Escape: "escape",
    ArrowLeft: "left",
    ArrowRight: "right",
    ArrowUp: "up",
    ArrowDown: "down",
    Home: "home",
    End: "end",
    PageUp: "pageup",
    PageDown: "pagedown",
    Equal: "0x18",
    Minus: "0x1b",
    BracketLeft: "0x21",
    BracketRight: "0x1e",
    Semicolon: "0x29",
    Quote: "0x27",
    Comma: "0x2b",
    Period: "0x2f",
    Slash: "0x2c",
    Backquote: "0x32",
    Backslash: "0x2a",
    Delete: "0x75",
  };
  const key =
    special[event.code] ??
    (/^Key[A-Z]$/.test(event.code)
      ? event.code.slice(3).toLowerCase()
      : /^Digit[0-9]$/.test(event.code)
        ? event.code.slice(5)
        : /^F([1-9]|1[0-9]|20)$/.test(event.code)
          ? event.code.toLowerCase()
          : null);
  if (!key) return null;
  const modifiers = [
    ["ctrl", event.ctrlKey],
    ["alt", event.altKey],
    ["shift", event.shiftKey],
    ["cmd", event.metaKey],
  ]
    .filter(([, on]) => on)
    .map(([value]) => value as string);
  return { modifiers, key };
}
