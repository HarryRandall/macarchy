import { type ReactNode, useRef } from "react";

import { cn } from "~/lib/cn";
import { useElementSize } from "~/lib/use-element-size";

import { axisText, type ChartTone, toneFill } from "./axis";
import { ChartFrame, useChartCursor } from "./chart-frame";
import { ChartTooltip, TipNote, TipTitle, TipValue } from "./chart-tooltip";
import { rampPercent } from "./scale";

interface HeatCell {
  /** The day or slot: "Tue 14 Oct". */
  label: string;
  /** The value in words for the tooltip and VoiceOver: "3 changes", "Passed". */
  value: string;
  /** A step on the accent ramp, from 0 (none) to `levels - 1`. */
  level?: number;
  /** A fixed meaning instead of the ramp, such as a check's result. */
  tone?: ChartTone;
  /** More context in the tooltip: the themes applied. */
  note?: ReactNode;
}

/** The accent mixed into the card for a ramp step; nothing at all is the muted well. */
function rampColour(level: number, levels: number) {
  const percent = rampPercent(level, levels);
  return percent === 0
    ? "var(--surface-muted)"
    : `color-mix(in srgb, var(--ui-accent) ${percent}%, var(--surface-card))`;
}

/**
 * A row of cells, one per day, coloured by how much happened or by a
 * result: theme changes over a month, a check's daily outcome. Hover or the
 * arrow keys show the day's value.
 */
function HeatStrip({
  label,
  cells,
  levels = 4,
  cellHeight = 40,
  gap = 3,
  startLabel,
  endLabel = "Today",
}: {
  /** What the strip shows: "Theme changes per day over the last 30 days". */
  label: string;
  cells: readonly HeatCell[];
  levels?: number;
  cellHeight?: number;
  gap?: number;
  /** Under the first cell; its label by default. */
  startLabel?: string;
  endLabel?: string;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const { width } = useElementSize(ref);
  const cursor = useChartCursor(cells.length);
  const count = cells.length;
  const cellWidth = Math.max((width - gap * (count - 1)) / Math.max(1, count), 2);
  const height = cellHeight + 22;
  const x = (index: number) => index * (cellWidth + gap);
  const hover = cursor.index;
  const active = hover === null ? undefined : cells[hover];

  return (
    <ChartFrame
      ref={ref}
      label={`${label}. Arrow keys move between days.`}
      announce={cursor.keyboard && active ? `${active.label}: ${active.value}` : null}
      {...cursor.frameProps}
    >
      <svg width={width} height={height} aria-hidden className="block">
        {cells.map((cell, index) => {
          const on = hover === index;
          const inset = on ? 0.75 : 0;
          return (
            // Cells are positional: the nth cell is the nth day.
            <g key={index}>
              <rect
                x={x(index) + inset}
                y={inset}
                width={Math.max(0, cellWidth - inset * 2)}
                height={cellHeight - inset * 2}
                rx={4}
                strokeWidth={on ? 1.5 : 0}
                className={cn(
                  "stroke-fg-secondary transition-opacity duration-150",
                  cell.tone ? toneFill[cell.tone] : undefined,
                )}
                style={{
                  fill: cell.tone ? undefined : rampColour(cell.level ?? 0, levels),
                  opacity: hover !== null && !on ? 0.55 : 1,
                }}
              />
              <rect
                x={x(index) - gap / 2}
                y={0}
                width={cellWidth + gap}
                height={height}
                fill="transparent"
                onMouseEnter={() => cursor.point(index)}
              />
            </g>
          );
        })}
        {count ? (
          <>
            <text x={0} y={height - 6} className={axisText}>
              {startLabel ?? cells[0]?.label}
            </text>
            <text x={width} y={height - 6} textAnchor="end" className={axisText}>
              {endLabel}
            </text>
          </>
        ) : null}
      </svg>
      {active && hover !== null ? (
        <ChartTooltip
          anchor={{ x: x(hover) + cellWidth / 2, y: cellHeight / 2 }}
          gap={cellWidth / 2 + 8}
          bounds={{ width, height }}
        >
          <TipTitle>{active.label}</TipTitle>
          <TipValue>{active.value}</TipValue>
          {active.note ? <TipNote>{active.note}</TipNote> : null}
        </ChartTooltip>
      ) : null}
    </ChartFrame>
  );
}

/** The ramp's key: "Fewer", one swatch per level, "More". */
function HeatScale({
  levels = 4,
  fewer = "Fewer",
  more = "More",
}: {
  levels?: number;
  fewer?: string;
  more?: string;
}) {
  return (
    <span className="flex items-center gap-1.5 text-caption text-fg-tertiary">
      {fewer}
      {Array.from({ length: levels }, (_, level) => (
        <span
          key={level}
          aria-hidden
          className="size-2.5 rounded-[3px]"
          style={{ background: rampColour(level, levels) }}
        />
      ))}
      {more}
    </span>
  );
}

export { type HeatCell, HeatScale, HeatStrip };
