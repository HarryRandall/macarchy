import { Toggle } from "@base-ui/react/toggle";
import { ToggleGroup } from "@base-ui/react/toggle-group";
import { cva, type VariantProps } from "class-variance-authority";
import { type ReactNode, useLayoutEffect, useRef, useState } from "react";

import { cn } from "~/lib/cn";
import { observeResize } from "~/lib/observe-resize";

const segmentVariants = cva(
  [
    "relative z-10 inline-flex items-center justify-center gap-1.5 rounded-[5px] font-medium whitespace-nowrap text-fg-secondary select-none",
    "transition-[background-color,color] duration-150 outline-none focus-visible:ring-2 focus-visible:ring-accent",
    "not-data-pressed:hover:bg-seg-hover hover:text-fg data-pressed:text-fg data-disabled:opacity-50",
    "[&_svg]:size-3.5 [&_svg]:shrink-0",
  ],
  {
    variants: {
      size: {
        sm: "h-[22px] px-2 text-small",
        /** Inside a settings row. */
        default: "h-[26px] px-2.5 text-detail",
        /** Switching a page's view, as Light, Dark and Auto. */
        prominent: "h-[30px] px-3 text-body",
      },
    },
    defaultVariants: { size: "default" },
  },
);

interface SegmentedOption<V extends string> {
  value: V;
  label: string;
  count?: number;
  /** A glyph before the label; mark it `aria-hidden`. */
  icon?: ReactNode;
}

interface Pill {
  left: number;
  width: number;
}

/**
 * A short exclusive choice in a sunken track. The chosen segment sits on a
 * raised pill that slides between options. Arrow keys move between them.
 */
function SegmentedControl<V extends string>({
  label,
  value,
  options,
  onValueChange,
  size,
  disabled,
  fill = false,
  className,
}: VariantProps<typeof segmentVariants> & {
  label: string;
  value: V;
  options: readonly SegmentedOption<V>[];
  onValueChange: (value: V) => void;
  disabled?: boolean;
  /** Stretch to the container, sharing the width equally. */
  fill?: boolean;
  className?: string;
}) {
  const groupRef = useRef<HTMLDivElement>(null);
  const [pill, setPill] = useState<Pill | null>(null);
  // The first placement is drawn without sliding in from the left edge.
  const [settled, setSettled] = useState(false);

  useLayoutEffect(() => {
    const group = groupRef.current;
    if (!group) return;
    const measure = () => {
      const chosen = group.querySelector<HTMLElement>("[data-pressed]");
      const next = chosen ? { left: chosen.offsetLeft, width: chosen.offsetWidth } : null;
      setPill((current) =>
        current?.left === next?.left && current?.width === next?.width ? current : next,
      );
    };
    measure();
    const stop = observeResize(group, measure);
    // From the next frame on, a new choice slides rather than jumps.
    const frame = requestAnimationFrame(() => setSettled(true));
    return () => {
      cancelAnimationFrame(frame);
      stop();
    };
    // oxlint-disable-next-line react/exhaustive-effect-dependencies -- the pressed segment moves when the value or options change, which no resize reports.
  }, [value, options]);

  return (
    <ToggleGroup
      ref={groupRef}
      aria-label={label}
      value={[value]}
      disabled={disabled}
      loopFocus
      onValueChange={(next) => {
        // A pressed segment cannot be released into "nothing chosen".
        const chosen = next[0];
        if (chosen !== undefined) onValueChange(chosen as V);
      }}
      data-slot="segmented-control"
      className={cn(
        "relative isolate inline-flex shrink-0 items-center gap-0.5 rounded-tile bg-seg-track p-[3px] ring-1 ring-seg-ring ring-inset",
        fill && "flex w-full [&>button]:flex-1",
        className,
      )}
    >
      {pill ? (
        <span
          aria-hidden
          className={cn(
            "absolute inset-y-[3px] left-0 rounded-[5px] bg-seg-pill shadow-seg-pill",
            settled && "transition-[transform,width] duration-200 ease-glide",
          )}
          style={{ width: pill.width, transform: `translateX(${pill.left}px)` }}
        />
      ) : null}
      {options.map((option) => (
        <Toggle key={option.value} value={option.value} className={segmentVariants({ size })}>
          {option.icon}
          {option.label}
          {option.count === undefined ? null : (
            <span className="rounded-key bg-muted px-1 text-caption text-fg-secondary tabular-nums">
              {option.count}
            </span>
          )}
        </Toggle>
      ))}
    </ToggleGroup>
  );
}

export { SegmentedControl, type SegmentedOption };
