import { type MouseEvent, useId } from "react";

import { ChartFrame, useChartCursor } from "./chart-frame";
import { ChartTooltip } from "./chart-tooltip";
import { areaPath, linear, linePath, nearestIndex } from "./scale";

const pad = { top: 4, bottom: 3, x: 3 };

/**
 * A small line of recent values, such as a service's CPU over the last
 * hour, with a crosshair that snaps to the nearest sample under the pointer
 * or the arrow keys. Missing samples are skipped. When `live` is off, only a
 * dashed baseline is drawn.
 */
function Sparkline({
  label,
  values,
  times,
  live = true,
  width = 128,
  height = 34,
  format = String,
}: {
  /** What the line measures: "AeroSpace CPU over the last hour". */
  label: string;
  values: readonly (number | null)[];
  /** A time for each value, shown in the tooltip: "14:05". */
  times: readonly string[];
  live?: boolean;
  width?: number;
  height?: number;
  format?: (value: number) => string;
}) {
  const gradient = `spark-${useId().replace(/[^\w-]/g, "")}`;
  const samples = live
    ? values.flatMap((value, index) => (value === null ? [] : [{ index, value }]))
    : [];
  const cursor = useChartCursor(samples.length);

  const peak = samples.reduce((max, sample) => Math.max(max, sample.value), 0);
  const base = height - pad.bottom;
  const x = linear([0, Math.max(1, values.length - 1)], [pad.x, width - pad.x]);
  const y = linear([0, Math.max(peak, 1) * 1.15], [base, pad.top]);
  const points = samples.map((sample) => ({ x: x(sample.index), y: y(sample.value) }));
  const active = cursor.index === null ? undefined : samples[cursor.index];
  const latest = samples[samples.length - 1];

  const describe = (sample: { index: number; value: number }) =>
    `${format(sample.value)} at ${times[sample.index] ?? ""}`.trim();

  const summary =
    live && latest
      ? `${label}: peak ${format(peak)}, now ${format(latest.value)}`
      : `${label}: no data while stopped`;

  const onMouseMove = (event: MouseEvent<HTMLDivElement>) => {
    if (!points.length) return;
    const rect = event.currentTarget.getBoundingClientRect();
    const pointer = ((event.clientX - rect.left) / rect.width) * width;
    cursor.point(
      nearestIndex(
        points.map((point) => point.x),
        pointer,
      ),
    );
  };

  return (
    <ChartFrame
      label={`${summary}. Arrow keys read each sample.`}
      announce={cursor.keyboard && active ? describe(active) : null}
      className="text-accent"
      style={{ width, height }}
      onMouseMove={onMouseMove}
      {...cursor.frameProps}
    >
      <svg width={width} height={height} aria-hidden className="block overflow-visible">
        <defs>
          <linearGradient id={gradient} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="currentColor" stopOpacity={0.18} />
            <stop offset="100%" stopColor="currentColor" stopOpacity={0} />
          </linearGradient>
        </defs>
        <line
          x1={0}
          x2={width}
          y1={base + 0.5}
          y2={base + 0.5}
          className="stroke-hairline"
          strokeDasharray={points.length ? undefined : "2 3"}
        />
        {points.length ? <path d={areaPath(points, base)} fill={`url(#${gradient})`} /> : null}
        {points.length > 1 ? (
          <path
            d={linePath(points)}
            fill="none"
            stroke="currentColor"
            strokeWidth={2}
            strokeLinejoin="round"
            strokeLinecap="round"
            opacity={active ? 0.85 : 1}
          />
        ) : null}
        {active ? (
          <>
            <line
              x1={x(active.index)}
              x2={x(active.index)}
              y1={0}
              y2={base}
              className="stroke-line-strong"
            />
            <circle
              cx={x(active.index)}
              cy={y(active.value)}
              r={3.5}
              fill="currentColor"
              strokeWidth={1.5}
              className="stroke-card"
            />
          </>
        ) : null}
      </svg>
      {active ? (
        <ChartTooltip
          anchor={{ x: x(active.index), y: y(active.value) }}
          bounds={{ width, height }}
          className="flex items-baseline gap-1.5 rounded-small px-1.5 py-0.5 text-caption"
        >
          <span className="font-semibold tabular-nums">{format(active.value)}</span>
          <span className="text-fg-tertiary tabular-nums">{times[active.index]}</span>
        </ChartTooltip>
      ) : null}
    </ChartFrame>
  );
}

export { Sparkline };
