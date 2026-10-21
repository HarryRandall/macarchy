import { flushSync } from "react-dom";

/**
 * Watches an element's size and delivers each change before the browser
 * paints. React state set in `onResize` commits synchronously, so geometry
 * derived from it never trails the layout by a frame. Returns the disconnect.
 */
export function observeResize(element: Element, onResize: (entry: ResizeObserverEntry) => void) {
  const observer = new ResizeObserver((entries) => {
    flushSync(() => {
      for (const entry of entries) onResize(entry);
    });
  });
  observer.observe(element);
  return () => observer.disconnect();
}
