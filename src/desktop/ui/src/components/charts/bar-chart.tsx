import { type ReactNode, useRef } from "react";

import { cn } from "~/lib/cn";
import { useElementSize } from "~/lib/use-element-size";

import { axisText, type ChartTone, edgeAnchor, toneBackground, toneFill } from "./axis";
import { ChartFrame, useChartCursor } from "./chart-frame";
import { ChartTooltip, TipRow, TipTitle } from "./chart-tooltip";
import { barPath, clamp, linear, zeroDomain } from "./scale";

const pad = { top: 8, bottom: 20 };

interface BarSeries {
  label: string;
  tone: ChartTone;
}

const single: readonly BarSeries[] = [{ label: "Value", tone: "accent" }];

/**
 * Columns over time, one per day or item, optionally stacked by series
 * (passed, warned, failed). A zero draws as a thin line so the day still
 * reads as counted. With `onSelect`, a click or Return chooses a bar, such
 * as filtering a list to that day, and Escape clears it.
 */
function BarChart({
  label,
  values,
  labels,
  series = single,
  xTicks,
  height = 132,
  maxBarWidth = 24,
  format = String,
  emphasiseLast = false,
  selected = null,
  onSelect,
  tooltip,
  axisWidth = 28,
}: {
  /** What the chart shows: "Snapshots per day over the last 30 days". */
  label: string;
  /** One entry per bar: a number, or one number per series when stacked. */
  values: readonly (number | readonly number[])[];
  /** One per bar, for the tooltip and VoiceOver: "Tue 14 Oct". */
  labels: readonly string[];
  /** The stack's layers from the bottom, with their colours. */
  series?: readonly BarSeries[];
  /** Indices to label under the axis. First and last by default. */
  xTicks?: readonly { index: number; label: string }[];
  height?: number;
  maxBarWidth?: number;
  format?: (value: number) => string;
  /** Draws the latest bar at full strength and the rest a little quieter. */
  emphasiseLast?: boolean;
  selected?: number | null;
  onSelect?: (index: number | null) => void;
  /** Replaces the tooltip's body for a bar. */
  tooltip?: (index: number) => ReactNode;
  axisWidth?: number;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const { width } = useElementSize(ref);
  const count = values.length;
  const stacks = values.map((value) => (typeof value === "number" ? [value] : [...value]));
  const totals = stacks.map((stack) => stack.reduce((sum, part) => sum + part, 0));
  const toggle = (index: number) => onSelect?.(selected === index ? null : index);
  const cursor = useChartCursor(count, {
    onActivate: onSelect ? toggle : undefined,
    onClear: onSelect ? () => onSelect(null) : undefined,
  });

  const scale = zeroDomain(Math.max(0, ...totals));
  const base = height - pad.bottom;
  const y = linear([0, scale.max], [base, pad.top]);
  const band = Math.max(0, width - axisWidth) / Math.max(1, count);
  const barWidth = clamp(band - 2, 2, maxBarWidth);
  const left = (index: number) => axisWidth + index * band;
  const hover = cursor.index;

  const swatch = (layer: number) => toneBackground[series[layer]?.tone ?? "accent"];
  const firstAndLast = [0, count - 1]
    .filter((index, position) => (position === 0 ? count > 0 : index > 0))
    .map((index) => ({ index, label: labels[index] ?? "" }));
  const ticks = xTicks ?? firstAndLast;

  const opacity = (index: number) => {
    if (hover !== null) return index === hover ? 1 : index === selected ? 0.7 : 0.45;
    if (selected !== null) return index === selected ? 1 : 0.3;
    if (emphasiseLast) return index === count - 1 ? 1 : 0.75;
    return 1;
  };

  const describe = (index: number) => {
    const stack = stacks[index] ?? [];
    const parts =
      stack.length > 1
        ? stack.map((part, layer) => `${series[layer]?.label ?? ""} ${format(part)}`).join(", ")
        : format(totals[index] ?? 0);
    return `${labels[index] ?? ""}: ${parts}${selected === index ? ", selected" : ""}`;
  };

  return (
    <ChartFrame
      ref={ref}
      label={`${label}. Arrow keys move between bars${onSelect ? ", Return chooses one" : ""}.`}
      announce={cursor.keyboard && hover !== null ? describe(hover) : null}
      {...cursor.frameProps}
    >
      <svg width={width} height={height} aria-hidden className="block">
        {scale.ticks.map((tick) => (
          <g key={tick}>
            <line
              x1={axisWidth}
              x2={width}
              y1={Math.round(y(tick)) + 0.5}
              y2={Math.round(y(tick)) + 0.5}
              className="stroke-hairline"
              strokeDasharray={tick === 0 ? undefined : "2 3"}
            />
            <text x={axisWidth - 8} y={y(tick)} dy="0.32em" textAnchor="end" className={axisText}>
              {tick}
            </text>
          </g>
        ))}
        {stacks.map((stack, index) => {
          const x = left(index) + (band - barWidth) / 2;
          const total = totals[index] ?? 0;
          const layers = stack.flatMap((part, layer) => (part > 0 ? [{ part, layer }] : []));
          let below = 0;
          return (
            // Bars are positional: the nth bar is the nth day.
            <g key={index}>
              {hover === index ? (
                <rect
                  x={left(index) + 1}
                  y={pad.top}
                  width={Math.max(0, band - 2)}
                  height={base - pad.top}
                  rx={5}
                  className="fill-hover"
                />
              ) : null}
              <g style={{ opacity: opacity(index) }} className="transition-opacity duration-150">
                {total > 0 ? (
                  layers.map(({ part, layer }, position) => {
                    const bottom = y(below) - (position > 0 ? 2 : 0);
                    below += part;
                    const top = y(below);
                    const last = position === layers.length - 1;
                    return (
                      <path
                        key={layer}
                        d={barPath(x, top, barWidth, Math.max(1.5, bottom - top), { round: last })}
                        className={toneFill[series[layer]?.tone ?? "accent"]}
                      />
                    );
                  })
                ) : (
                  <rect
                    x={x}
                    y={base - 2}
                    width={barWidth}
                    height={2}
                    rx={1}
                    className="fill-line-strong"
                  />
                )}
              </g>
            </g>
          );
        })}
        {ticks.map((tick, position) => (
          <text
            key={tick.index}
            x={left(tick.index) + band / 2}
            y={height - 4}
            textAnchor={edgeAnchor(position, ticks.length)}
            className={axisText}
          >
            {tick.label}
          </text>
        ))}
        {stacks.map((_, index) => (
          <rect
            key={index}
            x={left(index)}
            y={0}
            width={band}
            height={height}
            fill="transparent"
            className={cn(onSelect && "cursor-pointer")}
            onMouseEnter={() => cursor.point(index)}
            onClick={onSelect ? () => toggle(index) : undefined}
          />
        ))}
      </svg>
      {hover !== null ? (
        <ChartTooltip
          anchor={{ x: left(hover) + band / 2, y: y(Math.max(totals[hover] ?? 0, scale.max / 2)) }}
          bounds={{ width, height }}
        >
          {tooltip ? (
            tooltip(hover)
          ) : (
            <>
              <TipTitle>{labels[hover]}</TipTitle>
              {(stacks[hover] ?? []).map((part, layer) => (
                <TipRow
                  key={layer}
                  label={series[layer]?.label ?? ""}
                  value={format(part)}
                  swatch={series.length > 1 ? swatch(layer) : undefined}
                />
              ))}
            </>
          )}
        </ChartTooltip>
      ) : null}
    </ChartFrame>
  );
}

export { type BarSeries, BarChart };
