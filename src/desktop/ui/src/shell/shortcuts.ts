/** The window's own shortcuts. ⌘Q is the app menu's, so it is not here. */
export type ShellShortcut =
  "palette" | "sidebar" | "back" | "forward" | "shortcuts" | "logs" | "reload" | "folder";

interface KeyPress {
  key: string;
  metaKey: boolean;
  ctrlKey: boolean;
  altKey: boolean;
  shiftKey: boolean;
}

const plain: Record<string, ShellShortcut> = {
  k: "palette",
  "\\": "sidebar",
  "[": "back",
  "]": "forward",
  "/": "shortcuts",
};

const shifted: Record<string, ShellShortcut> = {
  l: "logs",
  r: "reload",
  o: "folder",
};

/** What a key press asks the window to do, if anything. ⌃⌘S also toggles the sidebar, as before. */
export function shortcutFor(press: KeyPress): ShellShortcut | null {
  const key = press.key.toLowerCase();
  if (!press.metaKey || press.altKey) return null;
  if (press.ctrlKey) return key === "s" && !press.shiftKey ? "sidebar" : null;
  return (press.shiftKey ? shifted[key] : plain[key]) ?? null;
}
