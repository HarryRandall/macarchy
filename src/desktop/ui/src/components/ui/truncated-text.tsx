import { useLayoutEffect, useRef, useState } from "react";

import { cn } from "~/lib/cn";
import { observeResize } from "~/lib/observe-resize";

import { Tooltip } from "./tooltip";

/**
 * One line that truncates with an ellipsis and, only while it is cut off,
 * shows in full in a tooltip and takes keyboard focus so the tooltip can be
 * reached. For names that can be any length: a theme, an app, a path.
 * Remount it (with `key`) when the text changes inside a fixed box.
 */
function TruncatedText({
  text,
  className,
}: {
  text: string;
  /** Type role, colour and layout; `truncate` is applied already. */
  className?: string;
}) {
  const ref = useRef<HTMLSpanElement>(null);
  const [truncated, setTruncated] = useState(false);
  useLayoutEffect(() => {
    const element = ref.current;
    if (!element) return;
    const measure = () => setTruncated(element.scrollWidth > element.clientWidth);
    measure();
    return observeResize(element, measure);
    // oxlint-disable-next-line react/exhaustive-effect-dependencies -- new text can overflow without the box resizing.
  }, [text]);
  return (
    // The full text is already the accessible text; the tooltip only shows it.
    <Tooltip content={text} disabled={!truncated} describe={false}>
      <span
        ref={ref}
        data-slot="truncated-text"
        // oxlint-disable-next-line jsx-a11y/no-noninteractive-tabindex -- a cut-off name must take focus, or the keyboard cannot open its tooltip.
        tabIndex={truncated ? 0 : undefined}
        className={cn(
          "block min-w-0 truncate rounded-small outline-none focus-visible:ring-2 focus-visible:ring-accent",
          className,
        )}
      >
        {text}
      </span>
    </Tooltip>
  );
}

export { TruncatedText };
