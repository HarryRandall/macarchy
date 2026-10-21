/**
 * Contrast around the theme's accent. The accent is the theme's identity, so
 * it is never replaced as a fill; what changes is the ink drawn on it and the
 * strokes that must stand out against the window's own surfaces.
 */

type Rgb = readonly [number, number, number];

/** `#rgb` or `#rrggbb`, as 0 to 255 channels; null for anything else. */
export function parseHex(hex: string): Rgb | null {
  const match = /^#([0-9a-f]{3}|[0-9a-f]{6})$/i.exec(hex.trim());
  if (!match?.[1]) return null;
  const digits =
    match[1].length === 3 ? [...match[1]].map((digit) => digit + digit).join("") : match[1];
  return map3([0, 2, 4], (start) => parseInt(digits.slice(start, start + 2), 16));
}

function map3(rgb: Rgb, run: (value: number, index: 0 | 1 | 2) => number): Rgb {
  return [run(rgb[0], 0), run(rgb[1], 1), run(rgb[2], 2)];
}

function toHex(rgb: Rgb): string {
  return `#${rgb.map((channel) => Math.round(channel).toString(16).padStart(2, "0")).join("")}`;
}

/** WCAG relative luminance, 0 for black to 1 for white. */
export function relativeLuminance(rgb: Rgb): number {
  const [r, g, b] = map3(rgb, (channel) => {
    const value = channel / 255;
    return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/** WCAG contrast ratio, from 1 (none) to 21 (black on white). */
export function contrastRatio(a: Rgb, b: Rgb): number {
  const first = relativeLuminance(a);
  const second = relativeLuminance(b);
  return (Math.max(first, second) + 0.05) / (Math.min(first, second) + 0.05);
}

const black: Rgb = [0, 0, 0];
const white: Rgb = [255, 255, 255];

/**
 * Ink for text and glyphs on an accent fill. White wherever it reaches 3:1,
 * as macOS draws it on its own blue (which black would beat on paper), and
 * black on accents too light for that.
 */
export function inkOn(fill: Rgb): Rgb {
  return contrastRatio(fill, white) >= 3 ? white : black;
}

function mix(from: Rgb, to: Rgb, amount: number): Rgb {
  return map3(from, (channel, index) => channel + (to[index] - channel) * amount);
}

/**
 * The accent, or the least change of it towards black or white that reaches
 * `minimum` contrast against every one of `surfaces`. 3:1 is the WCAG figure
 * for rings, focus indicators and other non-text marks.
 */
export function strokeOn(accent: Rgb, surfaces: readonly Rgb[], minimum = 3): Rgb {
  const worst = (colour: Rgb) =>
    Math.min(...surfaces.map((surface) => contrastRatio(colour, surface)));
  if (worst(accent) >= minimum) return accent;
  // Away from the surfaces: they share an appearance, so the first decides.
  const target = surfaces[0] && relativeLuminance(surfaces[0]) < 0.18 ? white : black;
  for (let step = 1; step <= 20; step++) {
    const candidate = mix(accent, target, step / 20);
    if (worst(candidate) >= minimum) return candidate;
  }
  return target;
}

/**
 * Surfaces an accent stroke is drawn on, per appearance: the page, cards and
 * bars. Mirrors index.css.
 */
const lightSurfaces: Rgb[] = [
  [0xf2, 0xf2, 0xf4],
  [0xff, 0xff, 0xff],
  [0xe9, 0xe9, 0xec],
];
const darkSurfaces: Rgb[] = [
  [0x1c, 0x1c, 0x1e],
  [0x2a, 0x2a, 0x2c],
  [0x24, 0x24, 0x26],
];

/**
 * CSS variables for an accent. `--accent-fg` is ink on an accent fill;
 * `--accent-stroke-light` and `--accent-stroke-dark` are what rings, focus
 * outlines and slider fills use in each appearance, which index.css picks
 * between. An accent that cannot be read sets only `--accent`.
 */
export function accentVariables(accent: string): Record<string, string> {
  const rgb = parseHex(accent);
  if (!rgb) return { "--accent": accent };
  return {
    "--accent": toHex(rgb),
    "--accent-fg": toHex(inkOn(rgb)),
    "--accent-stroke-light": toHex(strokeOn(rgb, lightSurfaces)),
    "--accent-stroke-dark": toHex(strokeOn(rgb, darkSurfaces)),
  };
}
