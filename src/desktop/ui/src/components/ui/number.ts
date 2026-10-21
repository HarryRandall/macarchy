export interface NumberBounds {
  min: number;
  max: number;
  /** Places kept after the point; the value is rounded to them. */
  decimals?: number;
}

/** Rounds to the bounds' places and pins inside them. */
export function clampNumber(value: number, { min, max, decimals = 0 }: NumberBounds) {
  const factor = 10 ** decimals;
  return Math.min(Math.max(Math.round(value * factor) / factor, min), max);
}

/**
 * The number a typed draft commits, or null when it should snap back:
 * blank and unparseable text never becomes a zero.
 */
export function parseNumberDraft(draft: string, bounds: NumberBounds): number | null {
  const trimmed = draft.trim();
  if (trimmed === "") return null;
  const parsed = Number(trimmed);
  if (!Number.isFinite(parsed)) return null;
  return clampNumber(parsed, bounds);
}

/** One step up or down, landing on the step grid from `min`. */
export function stepNumber(value: number, direction: 1 | -1, step: number, bounds: NumberBounds) {
  const steps = Math.round((value - bounds.min) / step) + direction;
  return clampNumber(bounds.min + steps * step, bounds);
}
