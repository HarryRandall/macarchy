import type { BorderAppearance } from "~/bridge/contract/borders";
import { cssColour, formatColour, parseColour } from "~/lib/colour";

export type CornerPreset = "system" | "square" | "rounded" | "custom";

/** The radii the presets write; macOS treats anything under 1 pt as square. */
export const squareRadius = 0.3;
export const roundedRadius = 8;
/** What macOS draws when Macarchy leaves corners alone, for the preview only. */
const systemPreviewRadius = 10;

export const defaultWidth = 6;

export function cornerPreset(radius: number | null): CornerPreset {
  if (radius === null) return "system";
  if (radius === squareRadius) return "square";
  if (radius === roundedRadius) return "rounded";
  return "custom";
}

export function presetRadius(preset: Exclude<CornerPreset, "custom">): number | null {
  if (preset === "system") return null;
  return preset === "square" ? squareRadius : roundedRadius;
}

/** The corner radius the preview draws, in pixels. */
export function previewRadius(radius: number | null): number {
  if (radius === null) return systemPreviewRadius;
  return radius < 1 ? 0 : radius;
}

/** A border colour for CSS, or the fallback when it is unset or unreadable. */
export function borderPaint(value: string | null, fallback: string): string {
  const colour = parseColour(value);
  return colour ? cssColour(colour) : fallback;
}

/** A border colour as `#rrggbb` for comparing with presets; null when unset. */
export function borderHex(value: string | null): string | null {
  const colour = parseColour(value);
  return colour ? formatColour(colour, "rgb") : null;
}

/** A preset `#rrggbb` written as borders wants it, keeping the current colour's opacity. */
export function withHex(current: string | null, hex: string): string | null {
  const colour = parseColour(hex);
  if (!colour) return null;
  return formatColour({ ...colour, a: parseColour(current)?.a ?? 255 }, "argb");
}

/** Unique `#rrggbb` presets in order, skipping unreadable or missing ones. */
export function presetColours(colours: readonly (string | null | undefined)[]): string[] {
  const seen = new Set<string>();
  for (const value of colours) {
    const colour = parseColour(value);
    if (colour) seen.add(formatColour(colour, "rgb"));
  }
  return [...seen];
}

/**
 * The arguments Macarchy passes to `borders` for this appearance, in the
 * order the core writes them. `style`, and `hidpi`, which follows it, come
 * from settings this page does not edit, so they are left out rather than
 * guessed.
 */
export function bordersArguments(appearance: BorderAppearance): string[] {
  const visible = appearance.visible;
  return [
    `width=${visible ? appearance.width.toFixed(1) : "0.0"}`,
    `blacklist="${appearance.excludedApps.join(",")}"`,
    `active_color=${visible ? (appearance.activeColour ?? "0xff45e8ff") : "0x00000000"}`,
    `inactive_color=${visible ? (appearance.inactiveColour ?? "0x00000000") : "0x00000000"}`,
  ];
}

/** Whether the draft's colours are still the theme's own. */
export function followsTheme(draft: BorderAppearance, defaults: BorderAppearance | null): boolean {
  return (
    !!defaults &&
    draft.activeColour === defaults.activeColour &&
    draft.inactiveColour === defaults.inactiveColour
  );
}

/** The edit that puts back the theme's colours and the standard visible width. */
export function themeReset(defaults: BorderAppearance | null): Partial<BorderAppearance> {
  return {
    width: defaultWidth,
    visible: true,
    ...(defaults
      ? { activeColour: defaults.activeColour, inactiveColour: defaults.inactiveColour }
      : {}),
  };
}

/** Whether applying `patch` to `draft` would change nothing. */
export function isNoop(draft: BorderAppearance, patch: Partial<BorderAppearance>): boolean {
  return (Object.keys(patch) as (keyof BorderAppearance)[]).every(
    (key) => JSON.stringify(draft[key]) === JSON.stringify(patch[key]),
  );
}
