import type { ShortcutBinding, ShortcutChord } from "~/bridge/protocol";

/**
 * A binding that only works in a skhd mode says so, so it does not read as a duplicate of
 * the same chord outside it.
 */
export function shortcutLabel(binding: ShortcutBinding, all: ShortcutBinding[]): string {
  const action = actionLabel(binding, all);
  return binding.modes.length ? `${action} (${binding.modes.join(", ")} mode)` : action;
}

function actionLabel(binding: ShortcutBinding, all: ShortcutBinding[]): string {
  if (binding.section && all.filter((item) => item.section === binding.section).length === 1)
    return binding.section;
  if (binding.activatesMode) return `Switch to ${binding.activatesMode} mode`;
  const command = binding.command;
  return (
    describeCommand(command) ??
    (command || (binding.appOverrides.length ? "Per-app action" : "Custom shortcut"))
  );
}

/**
 * The command with a full path to yabai or Macarchy's CLI cut to the tool's
 * name. Older setups wrote both in full, which hid what every shortcut does.
 * A script the app ships for the default shortcuts is cut to its file name.
 */
export function plainCommand(command: string): string {
  return command
    .replace(/(['"])[^'"]*\/(yabai|macarchy)\1(?=\s)/g, "$2")
    .replace(/(^|[\s;&|])\/\S*\/(yabai|macarchy)(?=\s)/g, "$1$2")
    .replace(/(['"])[^'"]*\/Contents\/Resources\/skhd\/scripts\/([\w.-]+)\1/g, "$2");
}

const directions: Record<string, string> = {
  west: "left",
  east: "right",
  north: "up",
  south: "down",
};

const spotify: Record<string, string> = {
  playpause: "Play or pause Spotify",
  "next track": "Next track in Spotify",
  "previous track": "Previous track in Spotify",
};

/** What a command Macarchy recognises does, in words; null for anything else. */
export function describeCommand(command: string): string | null {
  const media =
    /^\/usr\/bin\/pgrep -x Spotify >\/dev\/null && \/usr\/bin\/osascript -e 'tell application "Spotify" to (playpause|next track|previous track)'$/.exec(
      command,
    );
  if (media) return spotify[media[1]!]!;
  const parts = plainCommand(command)
    .trim()
    .split(/\s*(?:&&|;)\s*/);
  const [first, second, ...rest] = parts;
  if (!first || rest.length) return null;
  let match: RegExpExecArray | null;
  if ((match = /^yabai -m window --(focus|swap|warp) (west|east|north|south)$/.exec(first))) {
    const direction = directions[match[2]!]!;
    const verb = { focus: "Focus", swap: "Swap", warp: "Move window" }[match[1]!]!;
    if (!second) return `${verb} ${direction}`;
    if (match[1] !== "focus" && second === `yabai -m window --focus ${match[2]}`)
      return `${verb} ${direction} and follow`;
    return null;
  }
  if ((match = /^yabai -m window --space (\d+)$/.exec(first))) {
    if (!second) return `Move window to desktop ${match[1]}`;
    if (second === `yabai -m space --focus ${match[1]}`)
      return `Move window to desktop ${match[1]} and follow`;
    return null;
  }
  if (second === "yabai -m space --balance" && first === "yabai -m space --rotate 90")
    return "Rotate the layout";
  if (second) return null;
  if ((match = /^(?:yabai -m space --focus|macarchy space) (\d+)$/.exec(first)))
    return `Go to desktop ${match[1]}`;
  if ((match = /^macarchy space (\d+) --move$/.exec(first)))
    return `Move window to desktop ${match[1]} and follow`;
  if ((match = /^move-window-to-space\.sh (\d+)$/.exec(first)))
    return `Move window to desktop ${match[1]} and follow`;
  const single: Record<string, string> = {
    "yabai -m window --toggle zoom-fullscreen": "Fill the screen",
    "yabai -m window --toggle float": "Float or tile",
    "yabai -m window --toggle split": "Flip the split",
    "yabai -m space --rotate 90": "Rotate the layout",
    "yabai -m space --balance": "Balance the layout",
    "macarchy rules toggle": "Float or tile, remembered per app",
    "macarchy theme next": "Next theme",
    "macarchy theme prev": "Previous theme",
    "macarchy bar toggle": "Show or hide the menu bar",
  };
  if (single[first]) return single[first];
  if ((match = /^yabai -m window --ratio rel:(-?)[\d.]+$/.exec(first)))
    return match[1] ? "Shrink window" : "Grow window";
  return null;
}

export interface ShortcutFilters {
  search: string;
  modifiers: string[];
  scope: "all" | "global" | "perApp" | "disabled";
  section: string;
}
export const emptyFilters: ShortcutFilters = {
  search: "",
  modifiers: [],
  scope: "all",
  section: "",
};
/** Disabled bindings are listed too, but only under All and their own scope. */
function inScope(binding: ShortcutBinding, scope: ShortcutFilters["scope"]): boolean {
  if (scope === "all") return true;
  if (scope === "disabled") return binding.disabled;
  return !binding.disabled && (scope === "perApp") === !!binding.appOverrides.length;
}

export function filterBindings(all: ShortcutBinding[], filters: ShortcutFilters) {
  const query = filters.search.trim().toLowerCase();
  return all.filter(
    (binding) =>
      inScope(binding, filters.scope) &&
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

/**
 * The physical key, independent of Shift and Option's transformed characters. skhd calls
 * Backspace `backspace` and forward delete `delete`; keypad keys are keycodes so they stay
 * distinct from the main keys. Swift validates the key and settles its spelling.
 */
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
    Backspace: "backspace",
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
    NumpadDecimal: "0x41",
    NumpadMultiply: "0x43",
    NumpadAdd: "0x45",
    NumLock: "0x47",
    NumpadDivide: "0x4b",
    NumpadEnter: "0x4c",
    NumpadSubtract: "0x4e",
    NumpadEqual: "0x51",
    Numpad0: "0x52",
    Numpad1: "0x53",
    Numpad2: "0x54",
    Numpad3: "0x55",
    Numpad4: "0x56",
    Numpad5: "0x57",
    Numpad6: "0x58",
    Numpad7: "0x59",
    Numpad8: "0x5b",
    Numpad9: "0x5c",
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
