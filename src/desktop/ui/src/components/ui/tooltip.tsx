import { Tooltip as TooltipPrimitive } from "@base-ui/react/tooltip";
import { type ReactElement, type ReactNode, useId } from "react";

import { cn } from "~/lib/cn";

/**
 * One per surface. A label appears once the pointer has rested for 350 ms;
 * after one has shown, neighbours open at once, so sweeping along a toolbar
 * reads each label without waiting again.
 */
function TooltipProvider({ children, delay = 350 }: { children: ReactNode; delay?: number }) {
  return (
    <TooltipPrimitive.Provider delay={delay} closeDelay={0}>
      {children}
    </TooltipPrimitive.Provider>
  );
}

interface TooltipProps {
  /** Secondary help or a control's name. Never the only place essential status appears. */
  content: string;
  /** A shortcut shown after the label, such as "⇧⌘L". */
  keys?: string;
  /** The control the help describes; it must accept a ref and props. */
  children: ReactElement<Record<string, unknown>>;
  side?: "top" | "right" | "bottom" | "left";
  disabled?: boolean;
  /**
   * Also expose the text as the control's accessible description. Off when
   * the text only repeats the control's own name.
   */
  describe?: boolean;
}

/**
 * Studio's hover label: a small dark bubble that opens after a pause on
 * hover and at once on keyboard focus, and closes on Escape, a press or
 * blur. It flips and shifts to stay inside the window and is portalled
 * above scrolling content.
 */
function Tooltip({
  content,
  keys,
  children,
  side = "bottom",
  disabled,
  describe = true,
}: TooltipProps) {
  const descriptionId = useId();
  const described = describe && !disabled;
  return (
    <TooltipPrimitive.Root disabled={disabled}>
      {/* Only set when used, so a child's own description is not overwritten. */}
      <TooltipPrimitive.Trigger
        render={children}
        {...(described ? { "aria-describedby": descriptionId } : {})}
      />
      {described ? (
        <span id={descriptionId} className="sr-only">
          {content}
        </span>
      ) : null}
      <TooltipPrimitive.Portal>
        <TooltipPrimitive.Positioner
          side={side}
          sideOffset={side === "left" || side === "right" ? 10 : 8}
          collisionPadding={8}
          className="pointer-events-none z-[60]"
        >
          <TooltipPrimitive.Popup
            data-slot="tooltip"
            className={cn(
              "flex max-w-[280px] items-center gap-1.5 rounded-small border border-tip-border bg-tip px-2 py-[3px] text-meta font-medium text-balance text-tip-fg shadow-tip",
              "transition-opacity duration-100 ease-out data-ending-style:opacity-0 data-starting-style:opacity-0 data-instant:transition-none",
            )}
          >
            <span className="min-w-0">{content}</span>
            {keys ? (
              <span aria-hidden className="shrink-0 font-normal opacity-60">
                {keys}
              </span>
            ) : null}
          </TooltipPrimitive.Popup>
        </TooltipPrimitive.Positioner>
      </TooltipPrimitive.Portal>
    </TooltipPrimitive.Root>
  );
}

export { Tooltip, TooltipProvider };
