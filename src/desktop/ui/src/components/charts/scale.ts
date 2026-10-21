export interface Point {
  x: number;
  y: number;
}

export interface Size {
  width: number;
  height: number;
}

export function clamp(value: number, min: number, max: number) {
  return Math.min(Math.max(value, min), max);
}

/** Removes the float noise that repeated additions leave, so 0.1 * 3 labels as 0.3. */
function tidy(value: number) {
  return Number(value.toPrecision(12));
}

/** The nearest step of 1, 2, 2.5 or 5 times a power of ten at or above `raw`. */
export function niceStep(raw: number) {
  if (!(raw > 0) || !Number.isFinite(raw)) return 1;
  const power = 10 ** Math.floor(Math.log10(raw));
  const fraction = raw / power;
  const nice = [1, 2, 2.5, 5].find((candidate) => fraction <= candidate) ?? 10;
  return tidy(nice * power);
}

export interface Domain {
  min: number;
  max: number;
  ticks: number[];
}

/**
 * Gridlines from zero to just past `max` in about `count` even steps, for
 * counts and bars that should stand on a zero baseline.
 */
export function zeroDomain(max: number, count = 3): Domain {
  const step = niceStep(Math.max(max, 0) / count);
  const top = Math.max(step, Math.ceil(tidy(Math.max(max, 0) / step)) * step);
  return { min: 0, max: tidy(top), ticks: ticksBetween(0, top, step) };
}

/**
 * Gridlines framing `low` to `high` on round values, for a line whose
 * movement matters more than its distance from zero, such as a file size.
 */
export function fitDomain(low: number, high: number, count = 2): Domain {
  if (!Number.isFinite(low) || !Number.isFinite(high)) return zeroDomain(0, count);
  const span = high - low || Math.abs(high) || 1;
  const step = niceStep(span / count);
  const min = Math.floor(tidy(low / step)) * step;
  const max = Math.max(min + step, Math.ceil(tidy(high / step)) * step);
  return { min: tidy(min), max: tidy(max), ticks: ticksBetween(min, max, step) };
}

function ticksBetween(min: number, max: number, step: number) {
  const ticks: number[] = [];
  const count = Math.round((max - min) / step);
  for (let index = 0; index <= count; index++) ticks.push(tidy(min + index * step));
  return ticks;
}

/** Maps a value in `domain` to a pixel in `range`; a flat domain maps to the range's start. */
export function linear(domain: [number, number], range: [number, number]) {
  const [d0, d1] = domain;
  const [r0, r1] = range;
  const span = d1 - d0;
  return (value: number) => (span === 0 ? r0 : r0 + ((value - d0) / span) * (r1 - r0));
}

/** The index whose position is closest to `x`, or -1 when there are none. */
export function nearestIndex(positions: readonly number[], x: number) {
  let best = -1;
  let distance = Infinity;
  positions.forEach((position, index) => {
    const gap = Math.abs(position - x);
    if (gap < distance) {
      best = index;
      distance = gap;
    }
  });
  return best;
}

/**
 * A polyline through the points. A gap in the data (a null in the source)
 * should be passed as separate runs, so the line breaks rather than bridging.
 */
export function linePath(points: readonly Point[]) {
  return points.map((point, index) => `${index ? "L" : "M"}${point.x},${point.y}`).join("");
}

/** The line closed down to `baseline`, for the soft fill under it. */
export function areaPath(points: readonly Point[], baseline: number) {
  const first = points[0];
  const last = points[points.length - 1];
  if (!first || !last) return "";
  return `${linePath(points)}L${last.x},${baseline}L${first.x},${baseline}Z`;
}

/** Consecutive non-null runs as points, so a line can break at missing values. */
export function runs(
  values: readonly (number | null)[],
  point: (value: number, index: number) => Point,
) {
  const result: Point[][] = [];
  let current: Point[] = [];
  values.forEach((value, index) => {
    if (value === null) {
      if (current.length) result.push(current);
      current = [];
    } else {
      current.push(point(value, index));
    }
  });
  if (current.length) result.push(current);
  return result;
}

export interface BarShape {
  /** Columns grow up from a baseline; rows grow right from a label. */
  direction?: "up" | "right";
  radius?: number;
  /** Off for the lower parts of a stack, which stay square. */
  round?: boolean;
}

/**
 * A bar with its free end rounded: the top for a column, the right end for a
 * row. The radius shrinks to fit a short bar.
 */
export function barPath(
  x: number,
  y: number,
  width: number,
  height: number,
  { direction = "up", radius = 4, round = true }: BarShape = {},
) {
  if (width <= 0 || height <= 0) return "";
  if (direction === "right") {
    const r = round ? Math.min(radius, height / 2, width) : 0;
    return `M${x},${y}H${x + width - r}A${r},${r} 0 0 1 ${x + width},${y + r}V${y + height - r}A${r},${r} 0 0 1 ${x + width - r},${y + height}H${x}Z`;
  }
  const r = round ? Math.min(radius, width / 2, height) : 0;
  return `M${x},${y + height}V${y + r}A${r},${r} 0 0 1 ${x + r},${y}H${x + width - r}A${r},${r} 0 0 1 ${x + width},${y + r}V${y + height}Z`;
}

export interface Placement {
  left: number;
  top: number;
}

/**
 * A chart tooltip beside a point: to the right when it fits, else to the
 * left, centred on the point vertically and kept inside the chart.
 */
export function placeBeside(anchor: Point, tip: Size, bounds: Size, gap = 12): Placement {
  const right = anchor.x + gap;
  const left = right + tip.width <= bounds.width ? right : anchor.x - gap - tip.width;
  return {
    left: clamp(left, 0, Math.max(0, bounds.width - tip.width)),
    top: clamp(anchor.y - tip.height / 2, 0, Math.max(0, bounds.height - tip.height)),
  };
}

/**
 * A chart tooltip above a point, centred on it, dropping below `below`
 * (the bottom of the thing pointed at) when there is no room above.
 */
export function placeAbove(
  anchor: Point,
  tip: Size,
  bounds: Size,
  { below = anchor.y, gap = 8 }: { below?: number; gap?: number } = {},
): Placement {
  const above = anchor.y - gap - tip.height;
  const top = above >= 0 ? above : below + gap;
  return {
    left: clamp(anchor.x - tip.width / 2, 0, Math.max(0, bounds.width - tip.width)),
    top: clamp(top, 0, Math.max(0, bounds.height - tip.height)),
  };
}

export interface CursorKeys {
  /** Left and Right for columns and time; Up and Down for a list of rows. */
  orientation?: "horizontal" | "vertical";
  /** Where the first arrow press lands; the latest point by default. */
  start?: number;
}

/**
 * The index a key moves a chart's cursor to, or undefined when the key is
 * not a cursor key. With no cursor yet, any arrow lands on `start`.
 */
export function stepIndex(
  current: number | null,
  key: string,
  count: number,
  { orientation = "horizontal", start = count - 1 }: CursorKeys = {},
): number | undefined {
  if (count <= 0) return undefined;
  const back = orientation === "horizontal" ? "ArrowLeft" : "ArrowUp";
  const forward = orientation === "horizontal" ? "ArrowRight" : "ArrowDown";
  if (key === "Home") return 0;
  if (key === "End") return count - 1;
  if (key !== back && key !== forward) return undefined;
  if (current === null) return clamp(start, 0, count - 1);
  return clamp(current + (key === forward ? 1 : -1), 0, count - 1);
}

/**
 * How strongly a heat cell is tinted, as a percentage of the accent mixed
 * into the card. Zero stays empty; the rest climb evenly to full.
 */
export function rampPercent(level: number, levels: number) {
  if (levels <= 1) return level > 0 ? 100 : 0;
  const step = clamp(Math.round(level), 0, levels - 1);
  if (step === 0) return 0;
  const lightest = 40;
  return Math.round(lightest + ((100 - lightest) * (step - 1)) / Math.max(1, levels - 2));
}

/** Buckets a count into `levels` steps of a ramp, relative to the largest count. */
export function rampLevel(value: number, max: number, levels: number) {
  if (value <= 0 || max <= 0) return 0;
  return clamp(Math.ceil((value / max) * (levels - 1)), 1, levels - 1);
}
