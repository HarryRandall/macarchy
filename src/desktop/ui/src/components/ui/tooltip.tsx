import { Tooltip as TooltipPrimitive } from "@base-ui/react/tooltip";
import { type ReactElement, type ReactNode, useId } from "react";

import { cn } from "~/lib/cn";

/**
 * One per surface. Timings follow HoverHelp: show once the pointer has
 * settled, hide after a short grace so crossing neighbours does not flicker.
 */
function TooltipProvider({ children }: { children: ReactNode }) {
  return (
    <TooltipPrimitive.Provider delay={400} closeDelay={120}>
      {children}
    </TooltipPrimitive.Provider>
  );
}

interface TooltipProps {
  /** Secondary help. Never the only place essential status appears. */
  content: string;
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

function Tooltip({ content, children, side = "top", disabled, describe = true }: TooltipProps) {
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
        <TooltipPrimitive.Positioner side={side} sideOffset={10} collisionPadding={12}>
          <TooltipPrimitive.Popup
            className={cn(
              "max-w-60 rounded-control border border-hairline bg-popover/95 px-3 py-[9px] text-[12px] leading-[16px] text-fg shadow-[0_3px_10px_rgb(0_0_0/0.22)] backdrop-blur-xl",
              "origin-(--transform-origin) transition-[opacity,scale] duration-140 ease-out",
              "data-starting-style:scale-94 data-starting-style:opacity-0 data-ending-style:opacity-0",
            )}
          >
            {content}
          </TooltipPrimitive.Popup>
        </TooltipPrimitive.Positioner>
      </TooltipPrimitive.Portal>
    </TooltipPrimitive.Root>
  );
}

export { Tooltip, TooltipProvider };
