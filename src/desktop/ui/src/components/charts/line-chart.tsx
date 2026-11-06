import { type MouseEvent, type ReactNode, useId, useRef } from "react";

import { useElementSize } from "~/lib/use-element-size";

import { axisText, edgeAnchor } from "./axis";
import { ChartFrame, useChartCursor } from "./chart-frame";
import { ChartTooltip, TipRow, TipTitle } from "./chart-tooltip";
import { areaPath, fitDomain, linear, linePath, runs, zeroDomain } from "./scale";

const pad = { top: 8, bottom: 20, right: 6 };

/**
 * A line over time with dashed gridlines, an optional soft area, and a
 * crosshair that snaps to the nearest point under the pointer or the arrow
 * keys. Missing values break the line rather than bridging the gap. It
 * fills its container's width.
 */
function LineChart({
  label,
  values,
  labels,
  xTicks,
  height = 136,
  area = true,
  domain = "zero",
  format = String,
  tickFormat = format,
  valueLabel = "Value",
  tooltip,
  axisWidth = 36,
}: {
  /** What the chart shows: "Config size over the last 30 days". */
  label: string;
  values: readonly (number | null)[];
  /** One per value, for the tooltip and VoiceOver: "Tue 14 Oct". */
  labels: readonly string[];
  /** Indices to label under the axis, with their text. First, middle and last by default. */
  xTicks?: readonly { index: number; label: string }[];
  height?: number;
  area?: boolean;
  /** `zero` stands the line on a zero baseline; `fit` frames its range. */
  domain?: "zero" | "fit";
  format?: (value: number) => string;
  tickFormat?: (value: number) => string;
  /** The measure's name in the tooltip: "CPU". */
  valueLabel?: string;
  /** Replaces the tooltip's body for a point. */
  tooltip?: (index: number) => ReactNode;
  /** Room for the gridline labels on the left. */
  axisWidth?: number;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const { width } = useElementSize(ref);
  const gradient = `line-${useId().replace(/[^\w-]/g, "")}`;
  const cursor = useChartCursor(values.length);

  const present = values.filter((value): value is number => value !== null);
  const scale =
    domain === "fit"
      ? fitDomain(Math.min(...present), Math.max(...present))
      : zeroDomain(Math.max(0, ...present));
  const base = height - pad.bottom;
  const right = Math.max(axisWidth, width - pad.right);
  const x = linear([0, Math.max(1, values.length - 1)], [axisWidth, right]);
  const y = linear([scale.min, scale.max], [base, pad.top]);
  const lines = runs(values, (value, index) => ({ x: x(index), y: y(value) }));

  const ticks =
    xTicks ??
    [0, Math.floor((values.length - 1) / 2), values.length - 1]
      .filter((index, position, all) => index >= 0 && all.indexOf(index) === position)
      .map((index) => ({ index, label: labels[index] ?? "" }));

  const activeIndex = cursor.index;
  const activeValue = activeIndex === null ? null : (values[activeIndex] ?? null);

  const describe = (index: number) => {
    const value = values[index] ?? null;
    return `${labels[index] ?? ""}: ${value === null ? "no data" : format(value)}`;
  };

  const onMouseMove = (event: MouseEvent<SVGSVGElement>) => {
    const rect = event.currentTarget.getBoundingClientRect();
    const span = Math.max(1, width - pad.right - axisWidth);
    const fraction = (event.clientX - rect.left - axisWidth) / span;
    const index = Math.round(fraction * (values.length - 1));
    cursor.point(Math.min(Math.max(index, 0), values.length - 1));
  };

  return (
    <ChartFrame
      ref={ref}
      label={`${label}. Arrow keys move between points.`}
      announce={cursor.keyboard && activeIndex !== null ? describe(activeIndex) : null}
      className="text-accent"
      {...cursor.frameProps}
    >
      <svg
        width={width}
        height={height}
        aria-hidden
        className="block cursor-crosshair"
        onMouseMove={onMouseMove}
      >
        <defs>
          <linearGradient id={gradient} x1="0" x2="0" y1="0" y2="1">
            <stop offset="0%" stopColor="currentColor" stopOpacity={0.2} />
            <stop offset="100%" stopColor="currentColor" stopOpacity={0} />
          </linearGradient>
        </defs>
        {scale.ticks.map((tick) => (
          <g key={tick}>
            <line
              x1={axisWidth}
              x2={width - pad.right}
              y1={Math.round(y(tick)) + 0.5}
              y2={Math.round(y(tick)) + 0.5}
              className="stroke-hairline"
              strokeDasharray={tick === scale.min ? undefined : "2 3"}
            />
            <text x={axisWidth - 8} y={y(tick)} dy="0.32em" textAnchor="end" className={axisText}>
              {tickFormat(tick)}
            </text>
          </g>
        ))}
        {area
          ? lines.map((points, index) => (
              <path key={index} d={areaPath(points, base)} fill={`url(#${gradient})`} />
            ))
          : null}
        {lines.map((points, index) => (
          <path
            key={index}
            d={linePath(points)}
            fill="none"
            stroke="currentColor"
            strokeWidth={2}
            strokeLinejoin="round"
            strokeLinecap="round"
          />
        ))}
        {ticks.map((tick, position) => (
          <text
            key={tick.index}
            x={x(tick.index)}
            y={height - 4}
            textAnchor={edgeAnchor(position, ticks.length)}
            className={axisText}
          >
            {tick.label}
          </text>
        ))}
        {activeIndex !== null ? (
          <g pointerEvents="none">
            <line
              x1={x(activeIndex)}
              x2={x(activeIndex)}
              y1={pad.top}
              y2={base}
              className="stroke-line-strong"
              strokeDasharray="3 3"
            />
            {activeValue !== null ? (
              <circle
                cx={x(activeIndex)}
                cy={y(activeValue)}
                r={4}
                fill="currentColor"
                strokeWidth={2}
                className="stroke-card"
              />
            ) : null}
          </g>
        ) : null}
      </svg>
      {activeIndex !== null ? (
        <ChartTooltip
          anchor={{ x: x(activeIndex), y: activeValue === null ? base : y(activeValue) }}
          bounds={{ width, height }}
        >
          {tooltip ? (
            tooltip(activeIndex)
          ) : (
            <>
              <TipTitle>{labels[activeIndex]}</TipTitle>
              <TipRow
                label={valueLabel}
                value={activeValue === null ? "No data" : format(activeValue)}
              />
            </>
          )}
        </ChartTooltip>
      ) : null}
    </ChartFrame>
  );
}

export { LineChart };
