/**
 * Puts text on the clipboard. The async Clipboard API needs a secure context,
 * which a page on a custom scheme may not count as, so a selection copied
 * with `execCommand` stands in for it. Both need a click or key press to have
 * just happened. Rejects when neither works, so callers can say so.
 */
export async function copyText(text: string): Promise<void> {
  const clipboard = globalThis.navigator?.clipboard;
  if (clipboard?.writeText) {
    try {
      await clipboard.writeText(text);
      return;
    } catch {
      // Fall through to the selection copy.
    }
  }
  if (!copyBySelection(text)) throw new Error("The clipboard could not be written.");
}

function copyBySelection(text: string): boolean {
  if (typeof document === "undefined") return false;
  const area = document.createElement("textarea");
  area.value = text;
  area.setAttribute("readonly", "");
  area.style.position = "fixed";
  area.style.opacity = "0";
  const focused = document.activeElement;
  document.body.append(area);
  area.select();
  try {
    return document.execCommand("copy");
  } catch {
    return false;
  } finally {
    area.remove();
    if (focused instanceof HTMLElement) focused.focus();
  }
}
