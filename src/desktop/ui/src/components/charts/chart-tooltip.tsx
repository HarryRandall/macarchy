import { type ReactNode, useLayoutEffect, useRef, useState } from "react";

import { cn } from "~/lib/cn";
import { observeResize } from "~/lib/observe-resize";

import { placeAbove, placeBeside, type Point, type Size } from "./scale";

/**
 * The hover card inside a chart. It measures itself and stays inside the
 * chart's box: beside the point (right, else left) or above it (else below
 * `below`). Hidden from VoiceOver; the chart's frame announces the value.
 */
function ChartTooltip({
  anchor,
  bounds,
  place = "beside",
  below,
  gap,
  className,
  children,
}: {
  /** The point in the chart's own coordinates. */
  anchor: Point;
  /** The chart's size, which the card never leaves. */
  bounds: Size;
  place?: "beside" | "above";
  /** With `above`: the bottom of the target, where the card drops to. */
  below?: number;
  /** Space between the anchor and the card; clear a wide bar or cell with it. */
  gap?: number;
  className?: string;
  children: ReactNode;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const [size, setSize] = useState<Size>({ width: 0, height: 0 });
  // The card's content changes as the pointer moves, so follow its size.
  useLayoutEffect(() => {
    const element = ref.current;
    if (!element) return;
    const measure = () => {
      const width = element.offsetWidth;
      const height = element.offsetHeight;
      setSize((current) =>
        current.width === width && current.height === height ? current : { width, height },
      );
    };
    measure();
    return observeResize(element, measure);
  }, []);
  const { left, top } =
    place === "above"
      ? placeAbove(anchor, size, bounds, { below, gap })
      : placeBeside(anchor, size, bounds, gap);
  return (
    <div
      ref={ref}
      aria-hidden
      data-slot="chart-tooltip"
      className={cn(
        "pointer-events-none absolute z-10 rounded-tile border border-hairline bg-popover px-2.5 py-1.5 text-meta whitespace-nowrap text-fg shadow-chart-tip",
        className,
      )}
      style={{ left, top, visibility: size.width ? "visible" : "hidden" }}
    >
      {children}
    </div>
  );
}

/** The day or item the card describes. */
function TipTitle({ children }: { children: ReactNode }) {
  return <div className="mb-1 font-semibold text-fg">{children}</div>;
}

/** One measure in the card, with an optional colour key for stacked series. */
function TipRow({
  label,
  value,
  swatch,
}: {
  label: string;
  value: ReactNode;
  /** A `bg-*` class matching the series' colour. */
  swatch?: string;
}) {
  return (
    <div className="flex items-center justify-between gap-4 leading-[1.6]">
      <span className="flex items-center gap-1.5 text-fg-secondary">
        {swatch ? <span aria-hidden className={cn("size-2 rounded-[2px]", swatch)} /> : null}
        {label}
      </span>
      <span className="font-medium text-fg tabular-nums">{value}</span>
    </div>
  );
}

/** The one value of a single-series card, as "4 changes". */
function TipValue({ children }: { children: ReactNode }) {
  return <div className="font-medium text-fg tabular-nums">{children}</div>;
}

/** Context under the value, such as the themes applied or a hint to click. */
function TipNote({ children }: { children: ReactNode }) {
  return (
    <div className="mt-1 max-w-56 text-caption whitespace-normal text-fg-tertiary">{children}</div>
  );
}

export { ChartTooltip, TipNote, TipRow, TipTitle, TipValue };
