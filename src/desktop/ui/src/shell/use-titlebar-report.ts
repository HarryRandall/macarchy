import { type RefObject, useEffect } from "react";

import type { Rect } from "~/bridge/protocol";

export const TITLEBAR_HEIGHT = 44;

/** Marks an element in the bar as a control rather than part of the drag area. */
export const titlebarControl = { "data-titlebar-control": "" } as const;

function sameRects(a: Rect[], b: Rect[]) {
  return (
    a.length === b.length &&
    a.every(
      (rect, index) =>
        rect.x === b[index]?.x &&
        rect.y === b[index]?.y &&
        rect.width === b[index]?.width &&
        rect.height === b[index]?.height,
    )
  );
}

/**
 * Tells the host which parts of the top 44 px are controls, so a mouse-down
 * anywhere else drags the window. Reported on mount and whenever layout
 * moves, at most once per frame. The sidebar's collapse animates widths, so
 * the ResizeObserver fires each frame of it and the rects follow along.
 */
export function useTitlebarReport(
  rootRef: RefObject<HTMLElement | null>,
  report: (params: { height: number; controls: Rect[] }) => void,
) {
  useEffect(() => {
    const root = rootRef.current;
    if (!root) return;
    let frame = 0;
    let last: Rect[] | null = null;

    const send = () => {
      frame = 0;
      const controls: Rect[] = [];
      for (const element of root.querySelectorAll<HTMLElement>("[data-titlebar-control]")) {
        const box = element.getBoundingClientRect();
        if (box.width === 0 || box.height === 0 || box.top >= TITLEBAR_HEIGHT) continue;
        controls.push({
          x: Math.round(box.left),
          y: Math.round(box.top),
          width: Math.round(box.width),
          height: Math.round(box.height),
        });
      }
      if (last && sameRects(last, controls)) return;
      last = controls;
      report({ height: TITLEBAR_HEIGHT, controls });
    };
    const schedule = () => {
      if (!frame) frame = requestAnimationFrame(send);
    };

    // oxlint-disable-next-line macarchy/no-raw-resize-observer -- this reports native hit regions, not React state, so there is nothing to flush.
    const observer = new ResizeObserver(schedule);
    observer.observe(root);
    for (const element of root.querySelectorAll(
      "[data-titlebar-control], [data-titlebar-region]",
    )) {
      observer.observe(element);
    }
    root.addEventListener("transitionend", schedule);
    window.addEventListener("resize", schedule);
    schedule();

    return () => {
      cancelAnimationFrame(frame);
      observer.disconnect();
      root.removeEventListener("transitionend", schedule);
      window.removeEventListener("resize", schedule);
    };
  }, [rootRef, report]);
}
