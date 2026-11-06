/**
 * Colours as the files on disk spell them. borders and SketchyBar want
 * `0xAARRGGBB`; FIREFOX_ACCENT wants `#rrggbb`. Parsing accepts either, and
 * formatting writes the notation the caller asks for, so editing a colour and
 * saving it never silently changes how the file spells it. Mirrors the
 * SwiftUI app's `Color(macarchyHex:)` and `macarchyString`.
 */

export type ColourFormat = "rgb" | "argb";

/** sRGB channels from 0 to 255 and alpha from 0 to 255, all whole numbers. */
export interface Rgba {
  r: number;
  g: number;
  b: number;
  a: number;
}

/** Hue, saturation, brightness and alpha, each from 0 to 1. */
export interface Hsva {
  h: number;
  s: number;
  v: number;
  a: number;
}

/**
 * `0xAARRGGBB`, `#rrggbb`, and the eight-digit `#aarrggbb` the Swift parser
 * also accepts, in either case. Null for anything else, including empty.
 */
export function parseColour(raw: string | null | undefined): Rgba | null {
  let text = raw?.trim() ?? "";
  if (/^0x/i.test(text)) text = text.slice(2);
  if (text.startsWith("#")) text = text.slice(1);
  if (!/^(?:[0-9a-f]{6}|[0-9a-f]{8})$/i.test(text)) return null;
  const channel = (start: number) => parseInt(text.slice(start, start + 2), 16);
  if (text.length === 6) return { r: channel(0), g: channel(2), b: channel(4), a: 255 };
  return { a: channel(0), r: channel(2), g: channel(4), b: channel(6) };
}

const pair = (value: number) =>
  Math.min(255, Math.max(0, Math.round(value)))
    .toString(16)
    .padStart(2, "0");

/** `0xaarrggbb` or `#rrggbb`, lower case. The `rgb` form drops alpha. */
export function formatColour(colour: Rgba, format: ColourFormat): string {
  const rgb = `${pair(colour.r)}${pair(colour.g)}${pair(colour.b)}`;
  return format === "argb" ? `0x${pair(colour.a)}${rgb}` : `#${rgb}`;
}

/** The value rewritten in `format`, or null when it cannot be read. */
export function normaliseColour(raw: string | null | undefined, format: ColourFormat) {
  const parsed = parseColour(raw);
  return parsed ? formatColour(parsed, format) : null;
}

/** A CSS colour for painting a swatch. */
export function cssColour(colour: Rgba): string {
  const alpha = Math.round((colour.a / 255) * 1000) / 1000;
  return `rgb(${colour.r} ${colour.g} ${colour.b} / ${alpha})`;
}

export function rgbaToHsva({ r, g, b, a }: Rgba): Hsva {
  const red = r / 255;
  const green = g / 255;
  const blue = b / 255;
  const max = Math.max(red, green, blue);
  const delta = max - Math.min(red, green, blue);
  let h = 0;
  if (delta > 0) {
    if (max === red) h = ((green - blue) / delta + 6) % 6;
    else if (max === green) h = (blue - red) / delta + 2;
    else h = (red - green) / delta + 4;
  }
  return { h: h / 6, s: max === 0 ? 0 : delta / max, v: max, a: a / 255 };
}

export function hsvaToRgba({ h, s, v, a }: Hsva): Rgba {
  const sector = (((h % 1) + 1) % 1) * 6;
  const channel = (offset: number) => {
    const k = (offset + sector) % 6;
    return Math.round((v - v * s * Math.max(0, Math.min(k, 4 - k, 1))) * 255);
  };
  return { r: channel(5), g: channel(3), b: channel(1), a: Math.round(a * 255) };
}
