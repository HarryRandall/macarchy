/** Axis text in SVG: 10.5px tertiary ink with tabular figures. */
export const axisText = "fill-fg-tertiary text-axis tabular-nums";

/** The first axis label hangs right of its point and the last left, so neither is clipped. */
export function edgeAnchor(position: number, count: number) {
  if (position === 0) return "start";
  return position === count - 1 ? "end" : "middle";
}

/** Series colours by meaning, as SVG fills and as HTML backgrounds for keys. */
export const toneFill = {
  accent: "fill-accent",
  ok: "fill-success",
  warn: "fill-warning",
  danger: "fill-danger",
  muted: "fill-line-strong",
} as const;

export const toneBackground = {
  accent: "bg-accent",
  ok: "bg-success",
  warn: "bg-warning",
  danger: "bg-danger",
  muted: "bg-line-strong",
} as const;

export type ChartTone = keyof typeof toneFill;
